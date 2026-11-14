# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for species" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    c1 = Species.create!(biome: biome, name: "Lion", description: "Apex felid", themes: %w[carnivore predator])
    c2 = Species.create!(biome: biome, name: "Leopard", description: "Solitary felid", themes: %w[carnivore predator])

    result = Clustering::HeuristicLabeler.label([ c1, c2 ])
    assert_includes result[:shared_themes], "Carnivore"
    assert_includes result[:title], "Archetype"
  end

  test "extracts shared themes for organisms" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    sp = Species.create!(biome: biome, name: "Lion", description: "Felid")
    org1 = Organism.create!(species: sp, name: "Alpha Male", description: "Pride defender", themes: [ "leader", "territorial" ])
    org2 = Organism.create!(species: sp, name: "Beta Male", description: "Secondary male", themes: [ "leader", "patrol" ])

    result = Clustering::HeuristicLabeler.label([ org1, org2 ])
    assert_includes result[:shared_themes], "Leader"
    assert_includes result[:title], "Archetype"
  end
end
