# frozen_string_literal: true

class SpeciesController < ApplicationController
  include EmbeddableActions

  def show
    @species = Species.includes(:biome, :organisms).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "species/modal",
          locals: { species: @species }
        )
      end
    end
  end

  def generate_embedding
    @species = Species.find(params[:id])
    enqueue_embedding_generation(@species)
  end

  def populate
    PopulateSpeciesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_species_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_species_controls",
            action_path: populate_species_index_path,
            idle_label: "Discover Species",
            running_label: "Discovering Species...",
            running: true,
            status_message: "Discovering species across biomes with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to species_index_path, notice: "Discovering species across biomes with LLM..." }
    end
  end

  def populate_organisms
    @species = Species.find(params[:id])
    PopulateOrganismsJob.perform_later(species_id: @species.id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Discovering individual organisms for #{@species.name}..."
        render turbo_stream: turbo_stream.replace(
          "species_organisms_section",
          partial: "species/organisms_section",
          locals: { species: @species, status_message: flash.now[:notice], status_kind: :info }
        )
      end
      format.html { redirect_to species_path(@species), notice: "Discovering individual organisms for #{@species.name}..." }
    end
  end

  private

  def find_embeddable_record
    Species.find(params[:id])
  end
end
