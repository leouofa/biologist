# frozen_string_literal: true

class PopulateOrganismsJob < ApplicationJob
  STREAM_NAME = "organisms"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(species_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    species_list = if species_id.present?
                     Species.where(id: species_id).includes(:biome).to_a
    else
                     Species.includes(:biome).joins(:biome).order("biomes.name ASC, species.name ASC").to_a
    end

    if species_list.empty?
      msg = species_id.present? ? "Species with ID #{species_id} not found." : "No species found. Populate species first before discovering individual organisms."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_species: [] }
    end

    total_upserted, failed_species = populate_across_species(species_list)
    summary = build_summary(total_upserted: total_upserted, total_species: species_list.size, failed_species: failed_species)

    if failed_species.size == species_list.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_organisms: Organism.count, failed_species: failed_species }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_species: failed_species }
  rescue StandardError => e
    Rails.logger.error("[PopulateOrganismsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate organisms: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate organisms: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_species!(species)
    existing_names = species.organisms.ordered.pluck(:name)
    chat = OrganismDiscoveryAgent.create!(
      species_name: species.name,
      species_description: species.description,
      species_themes: species.themes,
      biome_name: species.biome.name,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(species))

    entries = Llm::JsonResponseParser.extract_list(response, key: "organisms")
    upserted = Organism.upsert_batch!(species, entries)
    raise "LLM response did not contain any valid organisms for #{species.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_species(species_list)
    total_upserted = 0
    failed_species = []

    species_list.each_with_index do |species, index|
      msg = "Discovering individual organisms for #{species.name} (#{index + 1}/#{species_list.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: species_list.size, species: species.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_species!(species)
    rescue StandardError => e
      Rails.logger.error("[PopulateOrganismsJob] Species=#{species.name} #{e.class}: #{e.message}")
      failed_species << species.name
    end

    [ total_upserted, failed_species ]
  end

  def discovery_prompt_for(species)
    "Identify 6 to 10 major, ecologically or biologically distinct individual organisms, morphs, castes, life-history stages, or phenotype exemplars in #{species.name} (#{species.biome.name}) and return them as a JSON list with name, description, and thematic tags."
  end

  def build_summary(total_upserted:, total_species:, failed_species:)
    total_organisms = Organism.count
    if failed_species.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'organism'.pluralize(total_upserted)} across #{total_species} #{'species'.pluralize(total_species)} (#{total_organisms} total)."
      }
    elsif failed_species.size == total_species
      {
        kind: :error,
        message: "Failed to populate organisms for all species: #{failed_species.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'organism'.pluralize(total_upserted)} (#{total_organisms} total). Failed species: #{failed_species.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    species_groups = Organism.grouped_by_species
    total_organisms_count = Organism.count
    species_count = Species.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_organisms_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_organisms_controls",
        action_path: Rails.application.routes.url_helpers.populate_organisms_path,
        idle_label: "Discover Organisms",
        running_label: "Discovering Organisms...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "organisms_list",
      partial: "pages/organisms_list",
      locals: {
        grouped_organisms: species_groups,
        species_groups: species_groups,
        total_organisms_count: total_organisms_count,
        species_count: species_count
      }
    )
  end
end
