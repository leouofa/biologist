# frozen_string_literal: true

require "test_helper"

class SpeciesTest < ActiveSupport::TestCase
  test "validates presence of name, description, and biome" do
    sp = Species.new(name: " ", description: " ")
    assert_not sp.valid?
    assert_includes sp.errors[:biome], "must exist"
    assert_includes sp.errors[:name], "can't be blank"
    assert_includes sp.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grassland biome.")
    sp = Species.create!(
      biome: biome,
      name: "  African   Elephant ",
      description: "  Largest terrestrial mammal.  ",
      themes: [ " megafauna ", "Herbivore", "MEGAFAUNA", "", nil ]
    )

    assert_equal "African Elephant", sp.name
    assert_equal "Largest terrestrial mammal.", sp.description
    assert_equal [ "megafauna", "Herbivore" ], sp.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    biome = Biome.create!(name: "Ocean", description: "Marine pelagic ecosystem.")
    sp = Species.create!(
      biome: biome,
      name: "Blue Whale",
      description: "Largest animal known to have ever existed.",
      themes: "cetacean, baleen filter feeder, pelagic, Cetacean"
    )

    assert_equal [ "cetacean", "baleen filter feeder", "pelagic" ], sp.themes
  end

  test "enforces case-insensitive uniqueness scoped per biome" do
    savanna = Biome.create!(name: "Savanna", description: "Grasslands.")
    desert = Biome.create!(name: "Desert", description: "Arid ecosystem.")

    Species.create!(biome: savanna, name: "Cheetah", description: "Fastest land animal.")

    same_group_dup = Species.new(biome: savanna, name: "cheetah", description: "Duplicate.")
    assert_not same_group_dup.valid?
    assert_includes same_group_dup.errors[:name], "has already been taken"

    other_biome_sp = Species.new(biome: desert, name: "Cheetah", description: "Saharan cheetah population.")
    assert other_biome_sp.valid?
  end

  test "upsert_batch! inserts new species and updates existing ones within a biome" do
    savanna = Biome.create!(name: "Savanna", description: "Grasslands.")
    desert = Biome.create!(name: "Desert", description: "Arid biome.")

    Species.create!(biome: savanna, name: "Lion", description: "Old description", themes: [ "apex predator" ])
    Species.create!(biome: desert, name: "Lion", description: "Desert lion", themes: [ "carnivore" ])

    results = Species.upsert_batch!(savanna, [
      { "name" => "  lion ", "description" => "Apex social felid.", "themes" => [ "apex predator", "pride hunter" ] },
      { "name" => "Zebra", "description" => "Striped equin herbivore.", "themes" => [ "herbivore", "herd" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Giraffe", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, savanna.species.count
    assert_equal 1, desert.species.count

    lion = savanna.species.find_by!("LOWER(name) = ?", "lion")
    assert_equal "lion", lion.name
    assert_equal "Apex social felid.", lion.description
    assert_equal [ "apex predator", "pride hunter" ], lion.themes

    zebra = savanna.species.find_by!(name: "Zebra")
    assert_equal [ "herbivore", "herd" ], zebra.themes
  end

  test "grouped_by_biome returns biome groups and species sorted alphabetically" do
    tundra = Biome.create!(name: "Tundra", description: "Arctic plains.")
    ocean = Biome.create!(name: "Ocean", description: "Marine waters.")
    Biome.create!(name: "Desert", description: "Empty biome.")

    Species.create!(biome: tundra, name: "Polar Bear", description: "Arctic apex predator.", themes: [ "carnivore" ])
    Species.create!(biome: tundra, name: "Arctic Fox", description: "Small fox.", themes: [ "scavenger" ])
    Species.create!(biome: ocean, name: "Orca", description: "Apex odontocete.", themes: [ "apex predator" ])
    Species.create!(biome: ocean, name: "Blue Whale", description: "Baleen whale.", themes: [ "baleen" ])

    groups = Species.grouped_by_biome
    assert_equal [ "Ocean", "Tundra" ], groups.map { |biome, _| biome.name }
    assert_equal [ "Blue Whale", "Orca" ], groups[0][1].map(&:name)
    assert_equal [ "Arctic Fox", "Polar Bear" ], groups[1][1].map(&:name)
  end

  test "destroying a biome destroys its associated species" do
    savanna = Biome.create!(name: "Savanna", description: "Grasslands.")
    Species.create!(biome: savanna, name: "Lion", description: "Apex predator.", themes: [ "predator" ])

    assert_difference("Species.count", -1) do
      savanna.destroy!
    end
  end

  test "embedding_input formats biome, name, description, and themes" do
    savanna = Biome.create!(name: "Savanna", description: "Grasslands.")
    sp = Species.create!(biome: savanna, name: "Lion", description: "Apex predator.", themes: [ "carnivore", "apex predator" ])

    expected = <<~TEXT.chomp
      Species / Population: Lion (Savanna)
      Description: Apex predator.
      Themes: carnivore, apex predator
    TEXT

    assert_equal expected, sp.embedding_input
    assert_not sp.embedded?
  end
end
