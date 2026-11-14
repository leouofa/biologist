# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateOrganismsJobTest < ActiveSupport::TestCase
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

  test "perform iterates through species, upserts organisms with themes, and streams progress" do
    savanna = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    lion = Species.create!(biome: savanna, name: "Lion", description: "Apex felid.", themes: [ "carnivore" ])
    cheetah = Species.create!(biome: savanna, name: "Cheetah", description: "Fastest felid.", themes: [ "cursorial" ])
    Organism.create!(species: lion, name: "Alpha Male", description: "Initial alpha male description", themes: [ "leader" ])

    calls = []
    responses = {
      "Lion" => <<~TEXT,
        <think>Listing Lion organisms.</think>
        ```json
        {
          "organisms": [
            { "name": "Alpha Male", "description": "Dominant pride defender.", "themes": ["leader", "territorial"] },
            { "name": "Hunter Female", "description": "Primary hunt coordinator.", "themes": ["hunter", "pack"] }
          ]
        }
        ```
      TEXT
      "Cheetah" => {
        "organisms" => [
          { "name": "Solitary Adult Male", "description": "High-speed pursuit predator.", "themes": [ "solitary", "sprinter" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(species_name:, species_description:, species_themes:, biome_name:, existing_names:) {
      calls << { species_name: species_name, species_description: species_description, species_themes: species_themes, biome_name: biome_name, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(species_name))
      end
      fake_chat
    }) do
      # 2 species * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateOrganismsJob::STREAM_NAME, 6) do
        PopulateOrganismsJob.perform_now
      end
    end

    assert_equal [ "Cheetah", "Lion" ], calls.map { |c| c[:species_name] } # Species ordered alphabetically
    assert_equal [], calls.first[:existing_names] # Cheetah has none initially
    assert_equal [ "Alpha Male" ], calls.second[:existing_names] # Lion has Alpha Male

    assert_equal 3, Organism.count
    alpha = lion.organisms.find_by!(name: "Alpha Male")
    assert_equal "Dominant pride defender.", alpha.description
    assert_equal [ "leader", "territorial" ], alpha.themes

    sprinter = cheetah.organisms.find_by!(name: "Solitary Adult Male")
    assert_equal [ "solitary", "sprinter" ], sprinter.themes
  end

  test "perform continues to remaining species if one species fails" do
    savanna = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    lion = Species.create!(biome: savanna, name: "Lion", description: "Felid.")
    cheetah = Species.create!(biome: savanna, name: "Cheetah", description: "Felid.")

    with_stubbed_agent_create(->(species_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Lion" if species_name == "Lion"

        OpenStruct.new(
          parsed: nil,
          content: {
            "organisms" => [
              { "name": "Solitary Hunter", "description": "Pursuit hunter.", "themes": [ "cursorial" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateOrganismsJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateOrganismsJob.perform_now }
      end
    end

    assert_equal 1, Organism.count
    assert_equal "Solitary Hunter", Organism.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = OrganismDiscoveryAgent.singleton_class
    original = OrganismDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
