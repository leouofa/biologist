# frozen_string_literal: true

require "test_helper"

class ClusterSnapshotTest < ActiveSupport::TestCase
  test "validates presence and inclusion" do
    snapshot = ClusterSnapshot.new
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:target_type], "can't be blank"
    assert_includes snapshot.errors[:level], "can't be blank"
    assert_includes snapshot.errors[:distance_threshold], "can't be blank"
    assert_includes snapshot.errors[:title], "can't be blank"

    snapshot.target_type = "Invalid"
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:target_type], "is not included in the list"

    snapshot.target_type = "Species"
    snapshot.level = 16
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:level], "is not included in the list"

    snapshot.level = 15
    snapshot.distance_threshold = 0.22
    snapshot.title = "Valid Title"
    assert snapshot.valid?
  end

  test "creates snapshot with groups and memberships and cascades destruction" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    sp = Species.create!(biome: biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore", "predator" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "Species",
      level: 5,
      distance_threshold: 0.22,
      title: "Test Snapshot",
      clusters_count: 1,
      items_count: 1
    )

    cluster_group = snapshot.cluster_groups.create!(
      name: "Apex Felid Guild",
      shared_themes: [ "Carnivore", "Predator" ],
      size: 1
    )

    membership = cluster_group.cluster_memberships.create!(
      record: sp
    )

    assert_equal 1, snapshot.cluster_groups.count
    assert_equal 1, snapshot.cluster_memberships.count
    assert_equal sp, cluster_group.cluster_memberships.first.record

    assert_difference("ClusterSnapshot.count", -1) do
      assert_difference("ClusterGroup.count", -1) do
        assert_difference("ClusterMembership.count", -1) do
          snapshot.destroy!
        end
      end
    end
  end
end
