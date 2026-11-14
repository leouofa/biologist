# frozen_string_literal: true

module Api
  module V1
    class BiomesController < BaseController
      before_action :set_biome, only: %i[show update destroy populate_species]

      def index
        scope = Biome.all
        scope = scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        records, meta = paginate(scope.order("name ASC"))
        include_species = boolean_param(:include_species, default: false)

        data = records.map do |c|
          Serializer.biome(c, include_species: include_species)
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.biome(@biome, include_species: boolean_param(:include_species, default: true))
        )
      end

      def create
        biome = Biome.create!(biome_params)
        render_success(Serializer.biome(biome), status: :created)
      end

      def update
        @biome.update!(biome_params)
        render_success(Serializer.biome(@biome))
      end

      def destroy
        @biome.destroy!
        render_success({ id: @biome.id, name: @biome.name, deleted: true })
      end

      def populate_species
        if sync_requested?
          result = PopulateSpeciesJob.new.perform(biome_id: @biome.id)
          render_success({ message: "Species populated for #{@biome.name}", result: result })
        else
          job = PopulateSpeciesJob.perform_later(biome_id: @biome.id)
          render_success({ job_id: job.job_id, status: "queued", biome_id: @biome.id }, status: :accepted)
        end
      end

      def populate
        if sync_requested?
          result = PopulateBiomesJob.new.perform
          render_success({ message: "Biomes populated", result: result })
        else
          job = PopulateBiomesJob.perform_later
          render_success({ job_id: job.job_id, status: "queued" }, status: :accepted)
        end
      end

      def upsert_batch
        entries = params.require(:biomes).map do |entry|
          entry.permit(:name, :description).to_h
        end
        upserted = Biome.upsert_batch!(entries)
        render_success(
          upserted.map { |c| Serializer.biome(c) },
          meta: { count: upserted.size }
        )
      end

      private

      def set_biome
        @biome = Biome.find(params[:id])
      end

      def biome_params
        params.require(:biome).permit(:name, :description)
      end
    end
  end
end
