# frozen_string_literal: true

class OrganismsController < ApplicationController
  include EmbeddableActions

  def show
    @organism = Organism.includes(species: :biome).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "organisms/modal",
          locals: { organism: @organism }
        )
      end
    end
  end

  def generate_embedding
    @organism = Organism.find(params[:id])
    enqueue_embedding_generation(@organism)
  end

  def populate
    PopulateOrganismsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_organisms_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_organisms_controls",
            action_path: populate_organisms_path,
            idle_label: "Discover Organisms",
            running_label: "Discovering Organisms...",
            running: true,
            status_message: "Discovering individual organisms across species with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to organisms_path, notice: "Discovering individual organisms across species with LLM..." }
    end
  end

  private

  def find_embeddable_record
    Organism.find(params[:id])
  end
end
