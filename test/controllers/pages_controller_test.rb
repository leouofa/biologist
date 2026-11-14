# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders empty state and populate button when no biomes exist" do
    get root_url

    assert_response :success
    assert_select "h1", "Biomes"
    assert_select "button", /Discover|Populate/
    assert_match "No biomes yet", response.body
  end

  test "home lists all biomes ordered by name" do
    Biome.create!(name: "Ocean", description: "Marine waters.")
    Biome.create!(name: "Savanna", description: "Grasslands.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Ocean"), :<, response.body.index("Savanna")
    assert_match "Marine waters.", response.body
    assert_match "Grasslands.", response.body
  end

  test "species renders empty state and populate button when no species exist" do
    get species_index_url

    assert_response :success
    assert_select "h1", "Species & Populations"
    assert_select "button", /Discover Species/
    assert_match "No species yet", response.body
  end

  test "species lists all species in a table grouped by biome headers with themes" do
    savanna = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    ocean = Biome.create!(name: "Ocean", description: "Marine waters.")

    Species.create!(biome: savanna, name: "Lion", description: "Apex felid.", themes: [ "apex predator", "carnivore" ])
    Species.create!(biome: ocean, name: "Blue Whale", description: "Baleen filter feeder.", themes: [ "cetacean", "pelagic" ])
    Species.create!(biome: ocean, name: "Orca", description: "Apex marine predator.", themes: [ "apex predator", "odontocete" ])

    get species_index_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Ocean/
    assert_select "table tbody tr th", /Savanna/
    assert_operator response.body.index("Ocean"), :<, response.body.index("Savanna")
    assert_match "Apex felid.", response.body
    assert_match "apex predator", response.body
    assert_match "cetacean", response.body
    assert_match "pelagic", response.body
  end

  test "organisms renders empty state, populate button, and top navbar link when no organisms exist" do
    get organisms_url

    assert_response :success
    assert_select "nav a[href=?]", organisms_path, text: "Individual Organisms"
    assert_select "h1", "Individual Organisms"
    assert_select "button", /Discover Organisms/
    assert_match "No individual organisms yet", response.body
  end

  test "organisms lists all organisms in a table grouped by species headers" do
    savanna = Biome.create!(name: "Savanna", description: "Grasslands.")
    ocean = Biome.create!(name: "Ocean", description: "Marine biome.")

    lion = Species.create!(biome: savanna, name: "Lion", description: "Felid.")
    orca = Species.create!(biome: ocean, name: "Orca", description: "Whale.")

    Organism.create!(species: lion, name: "Alpha Male", description: "Dominant pride leader.", themes: [ "territorial", "leader" ])
    Organism.create!(species: lion, name: "Hunter Lioness", description: "Hunt coordinator.", themes: [ "hunter" ])
    Organism.create!(species: orca, name: "Resident Matriarch", description: "Pod matriarch.", themes: [ "matriarch", "scout" ])

    get organisms_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Orca/
    assert_select "table tbody tr th", /Lion/
    assert_match "Alpha Male", response.body
    assert_match "Hunter Lioness", response.body
    assert_match "Resident Matriarch", response.body
    assert_match "Dominant pride leader.", response.body
  end
end
