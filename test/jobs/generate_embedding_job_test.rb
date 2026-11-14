# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform generates embedding for Species and broadcasts running and success states" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore", "predator" ])
    vector = Array.new(1024, 0.05)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(species), 2) do
        GenerateEmbeddingJob.perform_now("Species", species.id)
      end
    end

    species.reload
    assert species.embedded?
    assert_equal "qwen3-embedding:0.6b", species.embedding_model
    assert_not_nil species.embedded_at
    assert_equal 1024, species.embedding.size
  end

  test "perform generates embedding for Organism and broadcasts running and success states" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Lion", description: "Apex felid.", themes: [ "carnivore" ])
    organism = Organism.create!(species: species, name: "Alpha Male", description: "Dominant pride leader.", themes: [ "leader" ])
    vector = Array.new(1024, 0.02)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(organism), 2) do
        GenerateEmbeddingJob.perform_now("Organism", organism.id)
      end
    end

    organism.reload
    assert organism.embedded?
    assert_equal "qwen3-embedding:0.6b", organism.embedding_model
    assert_not_nil organism.embedded_at
    assert_equal 1024, organism.embedding.size
  end

  test "perform broadcasts error state when embedding generation fails" do
    biome = Biome.create!(name: "Savanna", description: "Tropical grasslands.")
    species = Species.create!(biome: biome, name: "Cheetah", description: "Fastest felid.")

    with_stubbed_generator(->(_text) { raise "Connection refused" }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(species), 2) do
        assert_nothing_raised do
          GenerateEmbeddingJob.perform_now("Species", species.id)
        end
      end
    end

    species.reload
    assert_not species.embedded?
  end

  private

  def with_stubbed_generator(callable)
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call, &callable)
    yield
  ensure
    singleton.define_method(:call, original)
  end
end
