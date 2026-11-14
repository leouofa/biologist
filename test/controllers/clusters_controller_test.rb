# frozen_string_literal: true

require "test_helper"

class ClustersControllerTest < ActionDispatch::IntegrationTest
  test "GET /clusters returns success for species" do
    get clusters_path
    assert_response :success
    assert_select "h1", "Embedding Clusters"
    assert_select "input#similarity_level[value='5']"
  end

  test "GET /clusters with tab=organisms returns success" do
    get clusters_path(tab: "organisms", level: 3)
    assert_response :success
    assert_select "h1", "Embedding Clusters"
  end

  test "GET /clusters with turbo_stream format returns frame stream" do
    get clusters_path(tab: "species", level: 4), as: :turbo_stream
    assert_response :success
    assert_includes response.body, %(turbo-stream action="update" target="clusters_content_frame")
  end

  test "GET /clusters with level=15 renders complete coverage without singletons" do
    get clusters_path(level: 15)
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters with full_coverage=true returns complete coverage" do
    get clusters_path(level: 6, full_coverage: "true")
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters renders entity links targeting cluster_modal frame" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    v = Array.new(1024, 0.1)
    Species.create!(biome: biome, name: "Lion Modal Test", description: "Lion", embedding: v)
    Species.create!(biome: biome, name: "Cheetah Modal Test", description: "Cheetah", embedding: v)

    get clusters_path(tab: "species", level: 5)
    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "Lion Modal Test"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "View details →"
  end

  test "GET /clusters with organisms tab renders organism links targeting cluster_modal frame" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Felid")
    v = Array.new(1024, 0.1)
    Organism.create!(species: species, name: "Alpha Male Modal Test", description: "Alpha male", themes: [ "leader" ], embedding: v)
    Organism.create!(species: species, name: "Hunter Lioness Modal Test", description: "Hunter", themes: [ "hunter" ], embedding: v)

    get clusters_path(tab: "organisms", level: 5)
    assert_response :success
    assert_select "a[data-turbo-frame='cluster_modal']", text: "Alpha Male Modal Test"
    assert_select "a[data-turbo-frame='cluster_modal']", text: "View details →"
  end

  test "POST /clusters/snapshot creates snapshot and redirects to it" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    v = Array.new(1024, 0.2)
    Species.create!(biome: biome, name: "Snap Species 1", description: "D1", themes: [ "carnivore" ], embedding: v)
    Species.create!(biome: biome, name: "Snap Species 2", description: "D2", themes: [ "carnivore" ], embedding: v)

    assert_difference "ClusterSnapshot.count", 1 do
      post snapshot_clusters_path, params: { tab: "species", level: 5, title: "Test Controller Snapshot" }
    end

    snapshot = ClusterSnapshot.last
    assert_equal "Test Controller Snapshot", snapshot.title
    assert_redirected_to cluster_snapshot_path(snapshot)
    follow_redirect!
    assert_response :success
  end
end
