# frozen_string_literal: true

module Api
  module V1
    class SpeciesController < BaseController
      before_action :set_species, only: %i[show update destroy neighbors generate_embedding populate_organisms]

      def index
        scope = Species.includes(:biome)
        scope = scope.where(biome_id: params[:biome_id]) if params[:biome_id].present?
        if params[:biome].present?
          scope = scope.joins(:biome).where("biomes.name ILIKE ?", "%#{params[:biome]}%")
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(species.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.where("species.name ILIKE :q OR species.description ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("species.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        include_organisms = boolean_param(:include_organisms, default: false)

        data = records.map do |s|
          Serializer.species(s, include_embedding: include_embedding, include_organisms: include_organisms)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = Species.includes(:biome)
        scope = scope.where(biome_id: params[:biome_id]) if params[:biome_id].present?

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |sp|
              dist = sp.try(:neighbor_distance)
              Serializer.species(sp, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.where("species.name ILIKE :q OR species.description ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |sp| Serializer.species(sp) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.species(
            @species,
            include_embedding: boolean_param(:include_embedding, default: false),
            include_organisms: boolean_param(:include_organisms, default: true)
          )
        )
      end

      def create
        sp = Species.create!(species_params)
        render_success(Serializer.species(sp), status: :created)
      end

      def update
        @species.update!(species_params)
        render_success(Serializer.species(@species))
      end

      def destroy
        @species.destroy!
        render_success({ id: @species.id, name: @species.name, deleted: true })
      end

      def neighbors
        unless @species.embedded?
          return render_error(code: "not_embedded", message: "Species has no embedding generated yet", status: :unprocessable_entity)
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 50)
        cross_biome_only = boolean_param(:cross_biome_only, default: false)

        scope = @species.nearest_neighbors(:embedding, distance: "cosine")
        scope = scope.where.not(biome_id: @species.biome_id) if cross_biome_only

        neighbors = scope.limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.species(neighbor, neighbor_distance: neighbor.neighbor_distance)
        end

        render_success(
          results,
          meta: {
            source_id: @species.id,
            source_name: @species.name,
            biome_id: @species.biome_id,
            cross_biome_only: cross_biome_only,
            count: results.size
          }
        )
      end

      def generate_embedding
        if sync_requested?
          result = @species.generate_embedding!
          render_success(
            Serializer.species(@species, include_embedding: true),
            meta: { embedding_model: result[:model], dimensions: result[:dimensions] }
          )
        else
          job = GenerateEmbeddingJob.perform_later("Species", @species.id)
          render_success({ job_id: job.job_id, status: "queued", id: @species.id }, status: :accepted)
        end
      end

      def populate_organisms
        if sync_requested?
          result = PopulateOrganismsJob.new.perform(species_id: @species.id)
          render_success({ message: "Individual organisms populated for #{@species.name}", result: result })
        else
          job = PopulateOrganismsJob.perform_later(species_id: @species.id)
          render_success({ job_id: job.job_id, status: "queued", species_id: @species.id }, status: :accepted)
        end
      end

      def populate
        biome_id = params[:biome_id].presence

        if sync_requested?
          result = PopulateSpeciesJob.new.perform(biome_id: biome_id)
          render_success({ message: "Species populated", result: result })
        else
          job = PopulateSpeciesJob.perform_later(biome_id: biome_id)
          render_success({ job_id: job.job_id, status: "queued", biome_id: biome_id }, status: :accepted)
        end
      end

      def upsert_batch
        biome = Biome.find(params[:biome_id])
        entries = params.require(:species).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = Species.upsert_batch!(biome, entries)
        render_success(
          upserted.map { |s| Serializer.species(s) },
          meta: { count: upserted.size, biome_id: biome.id }
        )
      end

      private

      def set_species
        @species = Species.find(params[:id])
      end

      def species_params
        params.require(:species).permit(:biome_id, :name, :description, themes: [])
      end
    end
  end
end
