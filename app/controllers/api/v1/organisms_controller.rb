# frozen_string_literal: true

module Api
  module V1
    class OrganismsController < BaseController
      before_action :set_organism, only: %i[show update destroy neighbors generate_embedding]

      def index
        scope = Organism.includes(species: :biome)
        scope = scope.where(species_id: params[:species_id]) if params[:species_id].present?
        if params[:biome_id].present?
          scope = scope.joins(:species).where(species: { biome_id: params[:biome_id] })
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(organisms.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.joins(:species).where("organisms.name ILIKE :q OR organisms.description ILIKE :q OR species.name ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("organisms.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        data = records.map do |b|
          Serializer.organism(b, include_embedding: include_embedding, include_species: true)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = Organism.includes(species: :biome)
        scope = scope.where(species_id: params[:species_id]) if params[:species_id].present?
        if params[:biome_id].present?
          scope = scope.joins(:species).where(species: { biome_id: params[:biome_id] })
        end

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |organism|
              dist = organism.try(:neighbor_distance)
              Serializer.organism(organism, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.joins(:species)
                               .where("organisms.name ILIKE :q OR organisms.description ILIKE :q OR species.name ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |b| Serializer.organism(b) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.organism(@organism, include_embedding: boolean_param(:include_embedding, default: false), include_species: true)
        )
      end

      def create
        species = Species.find(params.require(:organism).require(:species_id))
        organism = species.organisms.create!(organism_params)
        render_success(Serializer.organism(organism), status: :created)
      end

      def update
        @organism.update!(organism_params)
        render_success(Serializer.organism(@organism))
      end

      def destroy
        @organism.destroy!
        render_success({ id: @organism.id, species_id: @organism.species_id, deleted: true })
      end

      def neighbors
        unless @organism.embedded?
          return render_error(code: "not_embedded", message: "Organism has no embedding generated yet", status: :unprocessable_entity)
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 50)
        cross_species_only = boolean_param(:cross_species_only, default: false)

        scope = @organism.nearest_neighbors(:embedding, distance: "cosine")
        scope = scope.where.not(species_id: @organism.species_id) if cross_species_only

        neighbors = scope.limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.organism(neighbor, neighbor_distance: neighbor.neighbor_distance)
        end

        render_success(
          results,
          meta: {
            source_id: @organism.id,
            source_name: @organism.name,
            species_id: @organism.species_id,
            cross_species_only: cross_species_only,
            count: results.size
          }
        )
      end

      def generate_embedding
        if sync_requested?
          result = @organism.generate_embedding!
          render_success(
            Serializer.organism(@organism, include_embedding: true),
            meta: { embedding_model: result[:model], dimensions: result[:dimensions] }
          )
        else
          job = GenerateEmbeddingJob.perform_later("Organism", @organism.id)
          render_success({ job_id: job.job_id, status: "queued", id: @organism.id }, status: :accepted)
        end
      end

      def populate
        species_id = params[:species_id].presence

        if sync_requested?
          result = PopulateOrganismsJob.new.perform(species_id: species_id)
          render_success({ message: "Individual organisms populated", result: result })
        else
          job = PopulateOrganismsJob.perform_later(species_id: species_id)
          render_success({ job_id: job.job_id, status: "queued", species_id: species_id }, status: :accepted)
        end
      end

      def upsert_batch
        species = Species.find(params[:species_id])
        entries = params.require(:organisms).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = Organism.upsert_batch!(species, entries)
        render_success(
          upserted.map { |b| Serializer.organism(b) },
          meta: { count: upserted.size, species_id: species.id }
        )
      end

      private

      def set_organism
        @organism = Organism.find(params[:id])
      end

      def organism_params
        params.require(:organism).permit(:species_id, :name, :description, themes: [])
      end
    end
  end
end
