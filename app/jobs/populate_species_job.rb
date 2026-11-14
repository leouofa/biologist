# frozen_string_literal: true

class PopulateSpeciesJob < ApplicationJob
  STREAM_NAME = "species"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(biome_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    biomes = if biome_id.present?
               Biome.where(id: biome_id).to_a
    else
               Biome.ordered.to_a
    end

    if biomes.empty?
      msg = biome_id.present? ? "Biome with ID #{biome_id} not found." : "No biomes found. Populate biomes first before discovering species."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_biomes: [] }
    end

    total_upserted, failed_biomes = populate_across_biomes(biomes)
    summary = build_summary(total_upserted: total_upserted, total_biomes: biomes.size, failed_biomes: failed_biomes)

    if failed_biomes.size == biomes.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_species: Species.count, failed_biomes: failed_biomes }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_biomes: failed_biomes }
  rescue StandardError => e
    Rails.logger.error("[PopulateSpeciesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate species: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate species: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_biome!(biome)
    existing_names = biome.species.ordered.pluck(:name)
    chat = SpeciesDiscoveryAgent.create!(
      biome_name: biome.name,
      biome_description: biome.description,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(biome))

    entries = Llm::JsonResponseParser.extract_list(response, key: "species")
    upserted = Species.upsert_batch!(biome, entries)
    raise "LLM response did not contain any valid species for #{biome.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_biomes(biomes)
    total_upserted = 0
    failed_biomes = []

    biomes.each_with_index do |biome, index|
      msg = "Discovering species for #{biome.name} (#{index + 1}/#{biomes.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: biomes.size, biome: biome.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_biome!(biome)
    rescue StandardError => e
      Rails.logger.error("[PopulateSpeciesJob] Biome=#{biome.name} #{e.class}: #{e.message}")
      failed_biomes << biome.name
    end

    [ total_upserted, failed_biomes ]
  end

  def discovery_prompt_for(biome)
    "Find prominent, ecologically notable species and distinct populations belonging to #{biome.name} and return their names, descriptions, and thematic tags as JSON."
  end

  def build_summary(total_upserted:, total_biomes:, failed_biomes:)
    total_species_count = Species.count
    if failed_biomes.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'species'.pluralize(total_upserted)} across #{total_biomes} #{'biome'.pluralize(total_biomes)} (#{total_species_count} total)."
      }
    elsif failed_biomes.size == total_biomes
      {
        kind: :error,
        message: "Failed to populate species for all biomes: #{failed_biomes.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'species'.pluralize(total_upserted)} (#{total_species_count} total). Failed biomes: #{failed_biomes.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    biome_groups = Species.grouped_by_biome
    total_species_count = Species.count
    biomes_count = Biome.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_species_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_species_controls",
        action_path: Rails.application.routes.url_helpers.populate_species_index_path,
        idle_label: "Discover Species",
        running_label: "Discovering Species...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "species_list",
      partial: "pages/species_list",
      locals: {
        grouped_species: biome_groups,
        biome_groups: biome_groups,
        total_species_count: total_species_count,
        biomes_count: biomes_count
      }
    )
  end
end
