# frozen_string_literal: true

require "test_helper"

class Api::V1::OrganismsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.98 : 0.02 }

    @species = Species.create!(biome: @biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore" ])
    @other_species = Species.create!(biome: @biome, name: "Cheetah", description: "Fastest felid.", themes: [ "carnivore" ])

    @organism = Organism.create!(
      species: @species,
      name: "Alpha Male",
      description: "Dominant pride leader.",
      themes: [ "leader", "territorial" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/organisms returns list" do
    get api_v1_organisms_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal 1, json["data"].size
    assert_equal "Alpha Male", json["data"].first["name"]
    assert_equal "Lion", json["data"].first.dig("species", "name")
  end

  test "GET /api/v1/organisms/:id returns organism" do
    get api_v1_organism_url(@organism), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @organism.id, json.dig("data", "id")
    assert_equal "Alpha Male", json.dig("data", "name")
    assert_includes json.dig("data", "themes"), "leader"
  end

  test "POST /api/v1/organisms creates organism for a species" do
    assert_difference("Organism.count", 1) do
      post api_v1_organisms_url, params: {
        organism: {
          species_id: @other_species.id,
          name: "Solitary Adult Male",
          description: "High-speed pursuit predator.",
          themes: [ "solitary", "sprinter" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Solitary Adult Male", response.parsed_body.dig("data", "name")
    assert_equal @other_species.id, response.parsed_body.dig("data", "species_id")
  end

  test "PATCH /api/v1/organisms/:id updates organism" do
    patch api_v1_organism_url(@organism), params: {
      organism: {
        description: "Updated Alpha Male description."
      }
    }, as: :json
    assert_response :success
    assert_equal "Updated Alpha Male description.", @organism.reload.description
  end

  test "DELETE /api/v1/organisms/:id deletes organism" do
    assert_difference("Organism.count", -1) do
      delete api_v1_organism_url(@organism), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/organisms/:id/neighbors finds nearest organisms" do
    other_organism = Organism.create!(
      species: @species,
      name: "Hunter Lioness",
      description: "Primary pack coordinator.",
      themes: [ "hunter", "pack" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_organism_url(@organism), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal other_organism.id, json["data"].first["id"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/organisms/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_organism_url(@organism), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
