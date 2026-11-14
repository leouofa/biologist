# frozen_string_literal: true

module Api
  module V1
    class Serializer
      class << self
        def biome(record, include_species: false, species_count: nil)
          data = {
            id: record.id,
            name: record.name,
            description: record.description,
            created_at: record.created_at&.iso8601,
            updated_at: record.updated_at&.iso8601,
            species_count: species_count || record.species.size
          }

          if include_species && record.association(:species).loaded?
            data[:species] = record.species.map { |sp| species(sp, include_biome: false) }
          elsif include_species
            data[:species] = record.species.ordered.map { |sp| species(sp, include_biome: false) }
          end

          data
        end

        def species(record, include_embedding: false, include_organisms: false, include_biome: true, neighbor_distance: nil)
          data = {
            id: record.id,
            biome_id: record.biome_id,
            name: record.name,
            description: record.description,
            themes: record.themes || [],
            organisms_count: record.organisms.size,
            embedded: record.embedded?,
            embedding_model: record.embedding_model,
            embedded_at: record.embedded_at&.iso8601,
            embedding_dimensions: record.embedding_dimensions,
            created_at: record.created_at&.iso8601,
            updated_at: record.updated_at&.iso8601
          }

          data[:neighbor_distance] = neighbor_distance.to_f if neighbor_distance.present?

          if include_biome && record.association(:biome).loaded?
            data[:biome] = record.biome ? { id: record.biome.id, name: record.biome.name } : nil
          elsif include_biome && record.biome_id.present?
            b = record.biome
            data[:biome] = b ? { id: b.id, name: b.name } : nil
          end

          if include_organisms
            data[:organisms] = record.organisms.ordered.map { |o_rec| organism(o_rec, include_species: false) }
          end

          if include_embedding
            data[:embedding] = record.embedding&.to_a
          end

          data
        end

        def organism(record, include_embedding: false, include_species: true, neighbor_distance: nil)
          data = {
            id: record.id,
            species_id: record.species_id,
            name: record.name,
            description: record.description,
            themes: record.themes || [],
            embedded: record.embedded?,
            embedding_model: record.embedding_model,
            embedded_at: record.embedded_at&.iso8601,
            embedding_dimensions: record.embedding_dimensions,
            created_at: record.created_at&.iso8601,
            updated_at: record.updated_at&.iso8601
          }

          data[:neighbor_distance] = neighbor_distance.to_f if neighbor_distance.present?

          if include_species
            sp = record.species
            if sp
              b = sp.biome
              data[:species] = {
                id: sp.id,
                name: sp.name,
                biome_id: sp.biome_id,
                biome_name: b&.name
              }
            end
          end

          if include_embedding
            data[:embedding] = record.embedding&.to_a
          end

          data
        end

        def live_cluster_result(result, unembedded_count: 0)
          {
            target_type: result.target_class.name,
            level: result.level,
            distance_threshold: result.distance_threshold,
            full_coverage: result.full_coverage?,
            total_embedded_count: result.total_embedded_count,
            unembedded_count: unembedded_count,
            clusters_count: result.multi_clusters_count,
            singletons_count: result.singletons_count,
            largest_cluster_size: result.largest_cluster_size,
            generated_at: result.generated_at&.iso8601,
            clusters: result.clusters.map do |c|
              {
                id: c.id,
                name: c.name,
                shared_themes: c.shared_themes,
                size: c.size,
                biomes: c.biomes,
                members: c.records.map do |rec|
                  rec.is_a?(Species) ? species(rec, include_biome: true) : organism(rec, include_species: true)
                end
              }
            end,
            singletons: result.singletons.map do |rec|
              rec.is_a?(Species) ? species(rec, include_biome: true) : organism(rec, include_species: true)
            end
          }
        end

        def cluster_snapshot(snapshot, include_groups: false, include_members: false, include_reports: false)
          data = {
            id: snapshot.id,
            target_type: snapshot.target_type,
            level: snapshot.level,
            distance_threshold: snapshot.distance_threshold,
            title: snapshot.title,
            clusters_count: snapshot.clusters_count,
            items_count: snapshot.items_count,
            created_at: snapshot.created_at&.iso8601,
            updated_at: snapshot.updated_at&.iso8601
          }

          if include_groups
            groups_scope = snapshot.cluster_groups.by_size
            groups_scope = groups_scope.includes(cluster_memberships: eager_associations_for(snapshot.target_type)) if include_members
            data[:groups] = groups_scope.map { |g| cluster_group(g, include_members: include_members) }
          end

          if include_reports
            data[:reports] = snapshot.cluster_reports.ordered.map { |r| cluster_report(r) }
          end

          data
        end

        def cluster_group(group, include_members: true)
          data = {
            id: group.id,
            cluster_snapshot_id: group.cluster_snapshot_id,
            name: group.name,
            shared_themes: group.shared_themes || [],
            size: group.size,
            created_at: group.created_at&.iso8601,
            updated_at: group.updated_at&.iso8601
          }

          if include_members
            memberships = group.cluster_memberships.to_a
            data[:members] = memberships.filter_map do |m|
              rec = m.record
              next nil unless rec

              if rec.is_a?(Species)
                species(rec, include_biome: true)
              elsif rec.is_a?(Organism)
                organism(rec, include_species: true)
              else
                { id: rec.id, type: rec.class.name }
              end
            end
          end

          data
        end

        def cluster_membership(membership)
          {
            id: membership.id,
            cluster_group_id: membership.cluster_group_id,
            record_type: membership.record_type,
            record_id: membership.record_id,
            created_at: membership.created_at&.iso8601,
            record: if membership.record.is_a?(Species)
                      species(membership.record, include_biome: true)
                    elsif membership.record.is_a?(Organism)
                      organism(membership.record, include_species: true)
                    else
                      nil
                    end
          }
        end

        def cluster_report(report, include_summaries: false, include_sub_reports: false)
          data = {
            id: report.id,
            cluster_snapshot_id: report.cluster_snapshot_id,
            title: report.title,
            prompt: report.prompt,
            status: report.status,
            phase: report.phase,
            phase_description: report.phase_description,
            progress_percentage: report.progress_percentage,
            is_detailed: report.detailed?,
            batch_size: report.batch_size,
            parent_report_id: report.parent_report_id,
            detailed_report_ids: report.detailed_reports.pluck(:id),
            summarized_clusters_count: report.summarized_clusters_count,
            total_clusters_count: report.total_clusters_count,
            aggregated_batches_count: report.aggregated_batches_count,
            total_batches_count: report.total_batches_count,
            content: report.content,
            error_message: report.error_message,
            completed_at: report.completed_at&.iso8601,
            created_at: report.created_at&.iso8601,
            updated_at: report.updated_at&.iso8601
          }

          if include_summaries
            data[:summaries] = report.cluster_report_summaries.ordered.map { |s| cluster_report_summary(s) }
          end

          if include_sub_reports
            data[:sub_reports] = report.cluster_sub_reports.ordered.map { |sr| cluster_sub_report(sr) }
          end

          data
        end

        def cluster_report_summary(summary)
          {
            id: summary.id,
            cluster_report_id: summary.cluster_report_id,
            cluster_group_id: summary.cluster_group_id,
            cluster_group_name: summary.cluster_group&.name,
            position: summary.position,
            content: summary.content,
            created_at: summary.created_at&.iso8601,
            updated_at: summary.updated_at&.iso8601
          }
        end

        def cluster_sub_report(sub_report)
          {
            id: sub_report.id,
            cluster_report_id: sub_report.cluster_report_id,
            batch_index: sub_report.batch_index,
            cluster_group_ids: sub_report.cluster_group_ids || [],
            content: sub_report.content,
            created_at: sub_report.created_at&.iso8601,
            updated_at: sub_report.updated_at&.iso8601
          }
        end

        def settings_payload
          {
            species_stats: GenerateAllEmbeddingsJob.stats_for(Species),
            organism_stats: GenerateAllEmbeddingsJob.stats_for(Organism),
            embedding_config: {
              model: Llm::EmbeddingGenerator.configured_model,
              api_base: Llm::EmbeddingGenerator.configured_api_base,
              dimensions: Llm::EmbeddingGenerator::DIMENSIONS
            },
            llm_config: {
              model: ENV["OLLAMA_MODEL"],
              api_base: ENV["OLLAMA_API_BASE"],
              context_window: Llm::ModelRegistry.current_context_window,
              digest_char_budget: Llm::ModelRegistry.digest_char_budget,
              presets: Llm::ModelRegistry::CONTEXT_WINDOW_PRESETS
            }
          }
        end

        private

        def eager_associations_for(target_type)
          case target_type
          when "Species"
            { record: :biome }
          when "Organism"
            { record: { species: :biome } }
          else
            :record
          end
        end
      end
    end
  end
end
