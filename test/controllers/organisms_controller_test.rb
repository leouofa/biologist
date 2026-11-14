# frozen_string_literal: true

require "test_helper"

class OrganismsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateOrganismsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateOrganismsJob) do
      post populate_organisms_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Organisms...", response.body
  end

  test "populate enqueues PopulateOrganismsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateOrganismsJob) do
      post populate_organisms_url
    end

    assert_redirected_to organisms_url
  end

  test "show renders organism details and Generate Embedding button" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")
    organism = Organism.create!(species: species, name: "Alpha Male", description: "Dominant pride leader.", themes: [ "leader" ])

    get organism_url(organism)

    assert_response :success
    assert_match "Alpha Male", response.body
    assert_match "Lion", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")
    organism = Organism.create!(species: species, name: "Alpha Male", description: "Dominant pride leader.", themes: [ "leader" ])

    get organism_url(organism), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Alpha Male", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Organism Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")
    organism = Organism.create!(species: species, name: "Alpha Male", description: "Dominant pride leader.", themes: [ "leader" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Organism", organism.id ]) do
      post generate_embedding_organism_url(organism), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")
    organism = Organism.create!(species: species, name: "Alpha Male", description: "Dominant pride leader.", themes: [ "leader" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Organism", organism.id ]) do
      post generate_embedding_organism_url(organism)
    end

    assert_redirected_to organism_url(organism)
  end
end
