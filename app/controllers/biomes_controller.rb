# frozen_string_literal: true

class BiomesController < ApplicationController
  def populate
    PopulateBiomesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_controls",
            action_path: populate_biomes_path,
            idle_label: "Populate Biomes",
            running_label: "Discovering Biomes...",
            running: true,
            status_message: "Discovering major biomes with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to root_path, notice: "Biome discovery queued." }
    end
  end
end
