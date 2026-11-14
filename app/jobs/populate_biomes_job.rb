# frozen_string_literal: true

class PopulateBiomesJob < ApplicationJob
  queue_as :default

  STREAM_NAME = "populate_biomes"
  DISCOVERY_PROMPT = "Identify major biomes across Earth's biosphere (tropical rainforests, boreal taiga, temperate deciduous forests, grasslands and savannas, deserts, tundra, marine coral reefs, pelagic open ocean, abyssal hydrothermal vents, freshwater wetlands) and return their canonical names and descriptions as JSON."

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    existing_names = Biome.ordered.pluck(:name)
    chat = BiomeDiscoveryAgent.create!(existing_names: existing_names)
    response = chat.ask(DISCOVERY_PROMPT)

    entries = Llm::JsonResponseParser.extract_list(response, key: "biomes")
    upserted = Biome.upsert_batch!(entries)
    raise "LLM response did not contain any valid biomes." if upserted.empty?

    message = "Upserted #{upserted.size} #{'biome'.pluralize(upserted.size)} (#{Biome.count} total)."
    track_completed(message: message, result: { upserted_count: upserted.size, total_count: Biome.count })

    broadcast_state(
      status_message: message,
      status_kind: :success,
      running: false
    )
    { upserted_count: upserted.size, total_count: Biome.count }
  rescue StandardError => e
    Rails.logger.error("[PopulateBiomesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate biomes: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate biomes: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def broadcast_state(status_message:, status_kind:, running:)
    biomes = Biome.ordered.to_a

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_biomes_path,
        idle_label: "Populate Biomes",
        running_label: "Discovering Biomes...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "biomes_list",
      partial: "pages/biomes_list",
      locals: { biomes: biomes }
    )
  end
end
