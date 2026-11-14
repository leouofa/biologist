# frozen_string_literal: true

class BiomeDiscoveryAgent < ApplicationAgent
  inputs :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing biome names already in our database: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same biomes so records update cleanly without duplicates, " \
          "and include any missing major biomes as well."
      else
        "Include major, widely recognized biomes across terrestrial, marine, freshwater, and extreme/chemosynthetic ecological domains " \
          "(e.g., 'Tropical Rainforest', 'Boreal Forest (Taiga)', 'Temperate Deciduous Forest', 'Temperate Grasslands & Savannas', 'Hot & Arid Deserts', 'Arctic & Alpine Tundra', 'Coral Reefs & Shallow Marine Shelves', 'Pelagic Open Ocean', 'Abyssal & Hydrothermal Vent Ecosystems', 'Freshwater Rivers & Wetland Basins', 'Mangrove & Estuarine Systems', 'Subterranean & Endolithic Caves')."
      end

    <<~INSTRUCTIONS.squish
      You are an expert ecologist, evolutionary biologist, biogeographer, and planetary biosphere taxonomist.
      Identify major biomes, global ecological zones, and primary environmental regimes across Earth's biosphere.
      For each biome, provide its canonical name and a concise, high-signal description covering its characteristic climate/temperature/precipitation or depth regimes, primary productivity and nutrient cycling dynamics, dominant vegetation or biological matrix, and ecological challenges.
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"biomes":[{"name":"Tropical Rainforest","description":"Equatorial biome characterized by year-round high precipitation and temperatures, multilayered evergreen canopy architecture, hyper-dense species richness, and intense biotic competition for light and canopy niches."}]}
    INSTRUCTIONS
  end
end
