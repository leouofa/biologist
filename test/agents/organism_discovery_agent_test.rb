# frozen_string_literal: true

require "test_helper"

class OrganismDiscoveryAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! includes species context, biome name, existing organism names, and JSON instructions" do
    chat = OrganismDiscoveryAgent.create!(
      species_name: "Jaguar (Panthera onca)",
      species_description: "Apex obligate carnivore and keystone predator.",
      species_themes: [ "apex predator", "hypercarnivore" ],
      biome_name: "Tropical Rainforest",
      existing_names: [ "Alpha Male", "Cub" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Jaguar (Panthera onca)"
    assert_includes system_message.content, "Tropical Rainforest"
    assert_includes system_message.content, "Apex obligate carnivore and keystone predator."
    assert_includes system_message.content, "apex predator, hypercarnivore"
    assert_includes system_message.content, "Alpha Male, Cub"
    assert_includes system_message.content, "Adult Territorial Male (Alpha Breeder)"
    assert_includes system_message.content, '"organisms"'
    assert_includes system_message.content, '"themes"'
  end
end
