# frozen_string_literal: true

require "test_helper"

class Api::V1::BiomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
  end

  test "GET /api/v1/biomes returns list" do
    get api_v1_biomes_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert json["meta"].key?("total")
    names = json["data"].map { |p| p["name"] }
    assert_includes names, "Savanna"
  end

  test "GET /api/v1/biomes/:id returns single biome" do
    get api_v1_biome_url(@biome), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @biome.name, json.dig("data", "name")
  end

  test "POST /api/v1/biomes creates a new biome" do
    assert_difference("Biome.count", 1) do
      post api_v1_biomes_url, params: { biome: { name: "Ocean", description: "Marine waters." } }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Ocean", json.dig("data", "name")
  end

  test "PATCH /api/v1/biomes/:id updates a biome" do
    patch api_v1_biome_url(@biome), params: { biome: { description: "Updated description" } }, as: :json
    assert_response :success

    @biome.reload
    assert_equal "Updated description", @biome.description
  end

  test "DELETE /api/v1/biomes/:id removes a biome" do
    assert_difference("Biome.count", -1) do
      delete api_v1_biome_url(@biome), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "POST /api/v1/biomes/upsert_batch upserts multiple biomes" do
    payload = {
      biomes: [
        { name: "Savanna", description: "New Savanna description" },
        { name: "Tundra", description: "Arctic plains." }
      ]
    }

    assert_difference("Biome.count", 1) do
      post upsert_batch_api_v1_biomes_url, params: payload, as: :json
    end
    assert_response :success

    assert_equal "New Savanna description", @biome.reload.description
    assert Biome.find_by(name: "Tundra")
  end

  test "POST /api/v1/biomes/populate enqueues PopulateBiomesJob by default" do
    assert_enqueued_with(job: PopulateBiomesJob) do
      post populate_api_v1_biomes_url, as: :json
    end
    assert_response :accepted
    assert response.parsed_body.dig("data", "job_id").present?
  end

  test "POST /api/v1/biomes/:id/populate_species enqueues PopulateSpeciesJob" do
    assert_enqueued_with(job: PopulateSpeciesJob, args: [ { biome_id: @biome.id } ]) do
      post populate_species_api_v1_biome_url(@biome), as: :json
    end
    assert_response :accepted
  end
end
