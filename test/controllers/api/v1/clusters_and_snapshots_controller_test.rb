# frozen_string_literal: true

require "test_helper"

class Api::V1::ClustersAndSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @species_a = Species.create!(biome: @biome, name: "Lion", description: "Apex felid", themes: [ "carnivore" ], embedding: @vector_a, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)
    @species_b = Species.create!(biome: @biome, name: "Cheetah", description: "Fastest felid", themes: [ "carnivore" ], embedding: @vector_b, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)

    @snapshot = ClusterSnapshot.create!(
      target_type: "Species",
      level: 5,
      distance_threshold: 0.20,
      title: "Predator Core Snapshot",
      clusters_count: 1,
      items_count: 2
    )
    @group = @snapshot.cluster_groups.create!(name: "Predator Guild Archetypes", shared_themes: [ "carnivore" ], size: 2)
    @group.cluster_memberships.create!(record: @species_a)
    @group.cluster_memberships.create!(record: @species_b)
  end

  test "GET /api/v1/clusters returns live cluster computation" do
    get api_v1_clusters_url, params: { target_type: "Species", level: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Species", json.dig("data", "target_type")
    assert json.dig("data", "clusters").is_a?(Array)
  end

  test "POST /api/v1/clusters/snapshot persists a snapshot" do
    assert_difference("ClusterSnapshot.count", 1) do
      post snapshot_api_v1_clusters_url, params: { target_type: "Species", level: 5, title: "Custom Snapshot" }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Custom Snapshot", json.dig("data", "title")
    assert json.dig("data", "groups").is_a?(Array)
  end

  test "GET /api/v1/cluster_snapshots returns list" do
    get api_v1_cluster_snapshots_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal @snapshot.id, json["data"].first["id"]
  end

  test "GET /api/v1/cluster_snapshots/:id returns snapshot with groups and members" do
    get api_v1_cluster_snapshot_url(@snapshot), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Predator Core Snapshot", json.dig("data", "title")
    assert_equal 1, json.dig("data", "groups").size
    assert_equal 2, json.dig("data", "groups").first.dig("members").size
  end

  test "DELETE /api/v1/cluster_snapshots/:id deletes snapshot" do
    assert_difference("ClusterSnapshot.count", -1) do
      delete api_v1_cluster_snapshot_url(@snapshot), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/cluster_snapshots/:cluster_snapshot_id/cluster_groups lists snapshot groups" do
    get api_v1_cluster_snapshot_cluster_groups_url(@snapshot), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Predator Guild Archetypes", json["data"].first["name"]
  end

  test "GET /api/v1/cluster_groups/:id returns group with members" do
    get api_v1_cluster_group_url(@group), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Predator Guild Archetypes", json.dig("data", "name")
    assert_equal 2, json.dig("data", "members").size
  end
end
