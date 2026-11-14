# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for Species snapshot" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    sp1 = Species.create!(biome: biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore", "predator" ])
    sp2 = Species.create!(biome: biome, name: "Cheetah", description: "Fastest felid.", themes: [ "carnivore", "cursorial" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "Species",
      level: 5,
      distance_threshold: 0.20,
      title: "Predator Guilds",
      clusters_count: 1,
      items_count: 2
    )

    cluster_group = snapshot.cluster_groups.create!(name: "Savanna Carnivores", shared_themes: [ "carnivore" ], size: 2)
    cluster_group.cluster_memberships.create!(record: sp1)
    cluster_group.cluster_memberships.create!(record: sp2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "Predator Guilds"
    assert_includes digest, "Target Type: Species"
    assert_includes digest, "Savanna Carnivores"
    assert_includes digest, "Lion (Savanna)"
    assert_includes digest, "Cheetah (Savanna)"
  end

  test "builds digest for Organism snapshot" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Felid.")
    organism = Organism.create!(species: species, name: "Alpha Male", description: "Pride defender.", themes: [ "leader", "territorial" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "Organism",
      level: 10,
      distance_threshold: 0.25,
      title: "Organism Clusters",
      clusters_count: 1,
      items_count: 1
    )

    cluster_group = snapshot.cluster_groups.create!(name: "Territorial Pride Leaders", shared_themes: [ "leader" ], size: 1)
    cluster_group.cluster_memberships.create!(record: organism)

    report = snapshot.cluster_reports.create!(prompt: "Analyze territorial pride leaders")
    report.cluster_report_summaries.create!(
      cluster_group: cluster_group,
      content: "This cluster focuses on dominant breeding males.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: Organism"
    assert_includes digest, "Alpha Male (Lion, Savanna)"
    assert_includes digest, "dominant breeding males"
  end
end
