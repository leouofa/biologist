# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateSpeciesJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "perform iterates through biomes, upserts species with themes, and streams progress" do
    savanna = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    ocean = Biome.create!(name: "Ocean", description: "Marine waters.")
    Species.create!(biome: savanna, name: "Lion", description: "Initial lion description", themes: [ "carnivore" ])

    calls = []
    responses = {
      "Savanna" => <<~TEXT,
        <think>Listing Savanna species.</think>
        ```json
        {
          "species": [
            { "name": "Lion", "description": "Apex felid.", "themes": ["apex predator", "carnivore"] },
            { "name": "Zebra", "description": "Striped equin herbivore.", "themes": ["herbivore", "herd"] }
          ]
        }
        ```
      TEXT
      "Ocean" => {
        "species" => [
          { "name": "Blue Whale", "description": "Filter feeding mysticete.", "themes": [ "cetacean", "filter feeder" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(biome_name:, biome_description:, existing_names:) {
      calls << { biome_name: biome_name, biome_description: biome_description, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(biome_name))
      end
      fake_chat
    }) do
      # 2 biomes * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateSpeciesJob::STREAM_NAME, 6) do
        PopulateSpeciesJob.perform_now
      end
    end

    assert_equal [ "Ocean", "Savanna" ], calls.map { |c| c[:biome_name] } # Biome.ordered sorts alphabetically
    assert_equal [], calls.first[:existing_names] # Ocean has none initially
    assert_equal [ "Lion" ], calls.second[:existing_names] # Savanna has Lion

    assert_equal 3, Species.count
    lion = savanna.species.find_by!(name: "Lion")
    assert_equal "Apex felid.", lion.description
    assert_equal [ "apex predator", "carnivore" ], lion.themes

    whale = ocean.species.find_by!(name: "Blue Whale")
    assert_equal [ "cetacean", "filter feeder" ], whale.themes
  end

  test "perform continues to remaining biomes if one biome fails" do
    ocean = Biome.create!(name: "Ocean", description: "Marine waters.")
    savanna = Biome.create!(name: "Savanna", description: "Grasslands.")

    with_stubbed_agent_create(->(biome_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Savanna" if biome_name == "Savanna"

        OpenStruct.new(
          parsed: nil,
          content: {
            "species" => [
              { "name": "Blue Whale", "description": "Filter feeder.", "themes": [ "cetacean" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateSpeciesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateSpeciesJob.perform_now }
      end
    end

    assert_equal 1, Species.count
    assert_equal "Blue Whale", Species.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = SpeciesDiscoveryAgent.singleton_class
    original = SpeciesDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
