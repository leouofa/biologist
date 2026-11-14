# frozen_string_literal: true

class SpeciesDiscoveryAgent < ApplicationAgent
  inputs :biome_name, :biome_description, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing species/population names already in our database for this biome: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same species so records update cleanly without duplicates, " \
          "and include any missing notable species or populations as well."
      else
        "Use clear, canonical common and binomial names recognized in biology (e.g., 'Jaguar (Panthera onca)', 'Harpy Eagle (Harpia harpyja)', 'Leafcutter Ant (Atta cephalotes)', 'Strangler Fig (Ficus watkinsiana)', 'Giant Tube Worm (Riftia pachyptila)', 'Polar Bear (Ursus maritimus)', 'Emperor Penguin (Aptenodytes forsteri)')."
      end

    context_clause = biome_description.present? ? "Biome context: #{biome_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert evolutionary biologist, zoologist/botanist, and ecological taxonomist.
      Identify major and notable species, distinct populations, or keystone organisms belonging to or associated with #{biome_name}.
      #{context_clause}
      For each species or population, provide:
      1. Its canonical common and scientific name.
      2. A concise, informative description covering its taxonomic lineage, trophic level, functional niche, key physiological/morphological adaptations to its biome, and reproductive or life-history strategy.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["apex predator", "canopy specialist", "endotherm", "k-strategist", "keystone species"]).
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"species":[{"name":"Jaguar (Panthera onca)","description":"Apex obligate carnivore and keystone predator of the neotropical rainforest, possessing an exceptionally powerful bite adapted for crushing armored reptilian prey and regulating ungulate herbivore populations.","themes":["apex predator","keystone species","hypercarnivore","stalk-and-ambush","terrestrial mammal"]}]}
    INSTRUCTIONS
  end
end
