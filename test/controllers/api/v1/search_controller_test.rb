# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    @vector = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }

    @species = Species.create!(
      biome: @biome,
      name: "Lion",
      description: "Apex felid predator of African grasslands.",
      themes: [ "carnivore", "apex predator", "pride" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @organism = Organism.create!(
      species: @species,
      name: "Alpha Male",
      description: "Dominant pride defender and territorial breeder.",
      themes: [ "leader", "territorial", "breeder" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/search requires q parameter" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    assert_equal "blank_query", response.parsed_body.dig("error", "code")
  end

  test "GET /api/v1/search returns results for keyword search" do
    get api_v1_search_url, params: { q: "territorial", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "keyword", json.dig("meta", "mode")
  end

  test "GET /api/v1/species/search performs keyword search" do
    get search_api_v1_species_index_url, params: { q: "Lion", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Lion", json["data"].first["name"]
  end

  test "GET /api/v1/organisms/search performs keyword search" do
    get search_api_v1_organisms_url, params: { q: "territorial", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @organism.id, json["data"].first["id"]
  end
end
