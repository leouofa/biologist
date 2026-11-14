# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        target_type = params[:target_type].to_s.downcase.presence || "all"
        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        species_scope = Species.includes(:biome)
        organisms_scope = Organism.includes(species: :biome)

        if (mode == "semantic" || mode == "auto") && (species_scope.where.not(embedding: nil).exists? || organisms_scope.where.not(embedding: nil).exists?)
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            species_results = []
            if %w[all species].include?(target_type)
              species_results = species_scope.where.not(embedding: nil)
                                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                             .limit(limit)
                                             .map do |sp|
                                               {
                                                 type: "Species",
                                                 score: 1.0 - sp.try(:neighbor_distance).to_f,
                                                 data: Serializer.species(sp, neighbor_distance: sp.try(:neighbor_distance))
                                               }
                                             end
            end

            organism_results = []
            if %w[all organism organisms].include?(target_type)
              organism_results = organisms_scope.where.not(embedding: nil)
                                                .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                                .limit(limit)
                                                .map do |org|
                                                  {
                                                    type: "Organism",
                                                    score: 1.0 - org.try(:neighbor_distance).to_f,
                                                    data: Serializer.organism(org, neighbor_distance: org.try(:neighbor_distance))
                                                  }
                                                end
            end

            combined = (species_results + organism_results).sort_by { |item| -item[:score] }.take(limit)
            return render_success(combined, meta: { mode: "semantic", query: query, count: combined.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        # Keyword fallback
        species_kw = []
        if %w[all species].include?(target_type)
          species_kw = species_scope.where("species.name ILIKE :q OR species.description ILIKE :q", q: "%#{query}%")
                                    .limit(limit)
                                    .map { |sp| { type: "Species", data: Serializer.species(sp) } }
        end

        organism_kw = []
        if %w[all organism organisms].include?(target_type)
          organism_kw = organisms_scope.joins(:species)
                                       .where("organisms.name ILIKE :q OR organisms.description ILIKE :q OR species.name ILIKE :q", q: "%#{query}%")
                                       .limit(limit)
                                       .map { |org| { type: "Organism", data: Serializer.organism(org) } }
        end

        combined = (species_kw + organism_kw).take(limit)
        render_success(combined, meta: { mode: "keyword", query: query, count: combined.size })
      end
    end
  end
end
