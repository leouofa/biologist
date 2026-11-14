# frozen_string_literal: true

require "test_helper"

class Api::V1::SpeciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @species = Species.create!(
      biome: @biome,
      name: "Lion",
      description: "Apex felid predator of African grasslands.",
      themes: [ "carnivore", "apex predator", "pride" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/species returns list with filtering" do
    get api_v1_species_index_url, params: { biome_id: @biome.id, theme: "apex predator" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Lion", json["data"].first["name"]
    assert_equal false, json["data"].first.key?("embedding")
  end

  test "GET /api/v1/species/:id returns species with biome details" do
    get api_v1_species_url(@species), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Lion", json.dig("data", "name")
    assert_equal "Savanna", json.dig("data", "biome", "name")
  end

  test "GET /api/v1/species/:id with include_embedding=true returns raw vector" do
    get api_v1_species_url(@species), params: { include_embedding: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "embedding").is_a?(Array)
    assert_equal 1024, json.dig("data", "embedding").size
  end

  test "POST /api/v1/species creates a species" do
    assert_difference("Species.count", 1) do
      post api_v1_species_index_url, params: {
        species: {
          biome_id: @biome.id,
          name: "Cheetah",
          description: "Fastest terrestrial mammal.",
          themes: [ "carnivore", "cursorial" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Cheetah", response.parsed_body.dig("data", "name")
  end

  test "PATCH /api/v1/species/:id updates species" do
    patch api_v1_species_url(@species), params: { species: { description: "Updated Lion description" } }, as: :json
    assert_response :success
    assert_equal "Updated Lion description", @species.reload.description
  end

  test "DELETE /api/v1/species/:id deletes species" do
    assert_difference("Species.count", -1) do
      delete api_v1_species_url(@species), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/species/:id/neighbors finds nearest species" do
    other = Species.create!(
      biome: @biome,
      name: "Leopard",
      description: "Solitary ambush felid predator.",
      themes: [ "carnivore", "ambush" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_species_url(@species), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "Leopard", json["data"].first["name"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/species/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_species_url(@species), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
