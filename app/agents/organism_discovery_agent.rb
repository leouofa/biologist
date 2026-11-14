# frozen_string_literal: true

class OrganismDiscoveryAgent < ApplicationAgent
  inputs :species_name, :species_description, :species_themes, :biome_name, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing individual organism, morph, caste, or life-stage names already in our database for this species: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same organisms so records update cleanly without duplicates, " \
          "and include any missing key variants as well."
      else
        "Identify 6 to 10 major, ecologically or biologically distinct individual organisms, morphs, castes, life-history stages, sexual dimorphic forms, or ecotype exemplars within this species or population."
      end

    themes_list = Array(species_themes).compact_blank
    themes_clause = themes_list.any? ? "Species thematic tags: #{themes_list.join(', ')}." : ""
    desc_clause = species_description.present? ? "Species context: #{species_description}" : ""

    <<~INSTRUCTIONS.squish
      You are an expert organismal biologist, ethologist, and ecological physiologist.
      Identify 6 to 10 major, biologically distinct individual organisms, castes, morphotypes, life-history stages, or notable individual exemplars in #{species_name} (#{biome_name}).
      Ensure representation of distinct life stages (e.g., larva vs. reproductive adult), specialized castes or morphs (e.g., major soldier, worker, queen, melanistic morph), seasonal phenotypes, or distinct behavioral phenotypes.
      #{desc_clause}
      #{themes_clause}
      #{existing_clause}

      For each individual organism or phenotype exemplar, provide:
      1. Its descriptive designation (e.g., 'Adult Territorial Male (Alpha Breeder)', 'Melanistic Morphotype (Black Panther)', 'Major Worker (Soldier Caste)', 'Planktonic Larval Instar', 'Gravid Breeding Female').
      2. A concise, informative description covering its specific anatomy, metabolic/physiological state, behavioral role, somatic adaptations, and life-history significance within the population.
      3. A JSON array of 2 to 6 concise thematic tags as lowercase strings (e.g., ["reproductive adult", "territorial male", "hypertrophied mandible", "dispersal stage"]).

      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"organisms":[{"name":"Adult Territorial Male (Alpha Breeder)","description":"Fully matured adult male displaying maximum cranial bone density, peak musculoskeletal mass, and active testosterone-driven territorial patrol and scent-marking behavior across home range boundaries.","themes":["adult male","territorial defender","prime breeding phenotype","peak muscularity"]}]}
    INSTRUCTIONS
  end
end
