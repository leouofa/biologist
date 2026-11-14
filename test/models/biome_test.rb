# frozen_string_literal: true

require "test_helper"

class BiomeTest < ActiveSupport::TestCase
  test "validates presence of name and description" do
    biome = Biome.new(name: " ", description: " ")
    assert_not biome.valid?
    assert_includes biome.errors[:name], "can't be blank"
    assert_includes biome.errors[:description], "can't be blank"
  end

  test "normalizes name whitespace and enforces case-insensitive uniqueness" do
    first = Biome.create!(name: "  Tropical Rainforest   ", description: "Dense equatorial forest biome.")
    assert_equal "Tropical Rainforest", first.name

    duplicate = Biome.new(name: "tropical rainforest", description: "Duplicate.")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "upsert_batch! inserts new biomes and updates existing ones case-insensitively" do
    Biome.create!(name: "Tundra", description: "Old description")

    results = Biome.upsert_batch!([
      { "name" => "  tundra ", "description" => "Updated tundra description." },
      { "name" => "Taiga", "description" => "Boreal forest biome." },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Savanna", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, Biome.count

    tundra = Biome.find_by!("LOWER(name) = ?", "tundra")
    assert_equal "tundra", tundra.name
    assert_equal "Updated tundra description.", tundra.description

    taiga = Biome.find_by!(name: "Taiga")
    assert_equal "Boreal forest biome.", taiga.description
  end
end
