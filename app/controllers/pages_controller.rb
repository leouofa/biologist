# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @biomes = Biome.ordered
  end

  def species
    @biome_groups = Species.grouped_by_biome
    @total_species_count = Species.count
    @biomes_count = Biome.count
  end

  def organisms
    @species_groups = Organism.grouped_by_species
    @total_organisms_count = Organism.count
    @species_count = Species.count
  end
end
