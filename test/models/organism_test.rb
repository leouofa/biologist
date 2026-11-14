# frozen_string_literal: true

require "test_helper"

class OrganismTest < ActiveSupport::TestCase
  test "validates presence of name, description, and species" do
    organism = Organism.new(name: " ", description: " ")
    assert_not organism.valid?
    assert_includes organism.errors[:species], "must exist"
    assert_includes organism.errors[:name], "can't be blank"
    assert_includes organism.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grassland.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")
    organism = Organism.create!(
      species: species,
      name: "  Prideland Alpha Male   ",
      description: "  Dominant breeding male of pride.  ",
      themes: [ " territorial ", "Breeder", "TERRITORIAL", "", nil ]
    )

    assert_equal "Prideland Alpha Male", organism.name
    assert_equal "Dominant breeding male of pride.", organism.description
    assert_equal [ "territorial", "Breeder" ], organism.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    biome = Biome.create!(name: "Ocean", description: "Marine biome.")
    species = Species.create!(biome: biome, name: "Orca", description: "Apex odontocete.")
    organism = Organism.create!(
      species: species,
      name: "Resident Matriarch J-2",
      description: "Centenarian matriarch guiding pod foraging.",
      themes: "matriarch, pod leader, post-reproductive, Matriarch"
    )

    assert_equal [ "matriarch", "pod leader", "post-reproductive" ], organism.themes
  end

  test "enforces case-insensitive uniqueness scoped per species" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    lion = Species.create!(biome: biome, name: "Lion", description: "Felid.")
    leopard = Species.create!(biome: biome, name: "Leopard", description: "Solitary felid.")

    Organism.create!(species: lion, name: "Alpha Specimen", description: "Lead male.")

    same_species_dup = Organism.new(species: lion, name: "alpha specimen", description: "Duplicate.")
    assert_not same_species_dup.valid?
    assert_includes same_species_dup.errors[:name], "has already been taken"

    other_species_org = Organism.new(species: leopard, name: "Alpha Specimen", description: "Dominant leopard.")
    assert other_species_org.valid?
  end

  test "upsert_batch! inserts new organisms and updates existing ones within a species" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    lion = Species.create!(biome: biome, name: "Lion", description: "Felid.")
    leopard = Species.create!(biome: biome, name: "Leopard", description: "Felid.")

    Organism.create!(species: lion, name: "Alpha Male", description: "Old description", themes: [ "pride leader" ])
    Organism.create!(species: leopard, name: "Alpha Male", description: "Different species individual", themes: [ "solitary" ])

    results = Organism.upsert_batch!(lion, [
      { "name" => "  alpha male ", "description" => "Prime breeding pride leader.", "themes" => [ "pride leader", "territorial" ] },
      { "name" => "Senior Hunter Lioness", "description" => "Experienced pack coordinator.", "themes" => [ "hunter", "scout" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Subadult Nomad", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, lion.organisms.count
    assert_equal 1, leopard.organisms.count

    alpha = lion.organisms.find_by!("LOWER(name) = ?", "alpha male")
    assert_equal "alpha male", alpha.name
    assert_equal "Prime breeding pride leader.", alpha.description
    assert_equal [ "pride leader", "territorial" ], alpha.themes

    lioness = lion.organisms.find_by!(name: "Senior Hunter Lioness")
    assert_equal [ "hunter", "scout" ], lioness.themes
  end

  test "grouped_by_species returns species groups and organisms sorted alphabetically" do
    biome = Biome.create!(name: "Ocean", description: "Marine biome.")

    orca = Species.create!(biome: biome, name: "Orca", description: "Odontocete.")
    whale = Species.create!(biome: biome, name: "Blue Whale", description: "Mysticete.")

    Organism.create!(species: orca, name: "Matriarch", description: "Leader.", themes: [ "pod" ])
    Organism.create!(species: orca, name: "Calf", description: "Young.", themes: [ "juvenile" ])
    Organism.create!(species: whale, name: "Adult Bull", description: "Male.", themes: [ "pelagic" ])
    Organism.create!(species: whale, name: "Nursing Calf", description: "Young.", themes: [ "juvenile" ])

    groups = Organism.grouped_by_species
    assert_equal [ "Blue Whale", "Orca" ], groups.map { |sp, _| sp.name }
    assert_equal [ "Adult Bull", "Nursing Calf" ], groups[0][1].map(&:name)
    assert_equal [ "Calf", "Matriarch" ], groups[1][1].map(&:name)
  end

  test "destroying a species destroys its associated organisms" do
    biome = Biome.create!(name: "Ocean", description: "Marine biome.")
    orca = Species.create!(biome: biome, name: "Orca", description: "Whale.")
    Organism.create!(species: orca, name: "Matriarch", description: "Leader.", themes: [ "pod" ])

    assert_difference "Organism.count", -1 do
      orca.destroy
    end
  end

  test "embedding_input formats organism, species, biome, description, and themes" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")
    organism = Organism.new(
      species: species,
      name: "Alpha Male",
      description: "Dominant pride leader.",
      themes: [ "territorial", "breeder" ]
    )

    expected = <<~TXT.strip
      Individual Organism: Alpha Male (Lion, Savanna)
      Description: Dominant pride leader.
      Themes: territorial, breeder
    TXT

    assert_equal expected, organism.embedding_input
  end
end
