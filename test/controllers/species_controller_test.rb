# frozen_string_literal: true

require "test_helper"

class SpeciesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateSpeciesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateSpeciesJob) do
      post populate_species_index_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Species...", response.body
  end

  test "populate enqueues PopulateSpeciesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateSpeciesJob) do
      post populate_species_index_url
    end

    assert_redirected_to species_index_url
  end

  test "show renders species details and Generate Embedding button" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore" ])

    get species_url(species)

    assert_response :success
    assert_match "Lion", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore" ])

    get species_url(species), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Lion", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Species Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Species", species.id ]) do
      post generate_embedding_species_url(species), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Species", species.id ]) do
      post generate_embedding_species_url(species)
    end

    assert_redirected_to species_url(species)
  end
end
