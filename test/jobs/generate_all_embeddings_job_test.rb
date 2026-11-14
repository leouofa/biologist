# frozen_string_literal: true

require "test_helper"

class GenerateAllEmbeddingsJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform with only_missing: true skips already-embedded species and embeds missing ones" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    existing_vector = Array.new(1024, 0.1)
    lion = Species.create!(
      biome: biome,
      name: "Lion",
      description: "Apex predator.",
      embedding: existing_vector,
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    cheetah = Species.create!(biome: biome, name: "Cheetah", description: "Fastest felid.")

    new_vector = Array.new(1024, 0.2)
    called_texts = []

    with_stubbed_generator(->(text) {
      called_texts << text
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 2) do
        GenerateAllEmbeddingsJob.perform_now("Species", only_missing: true)
      end
    end

    assert_equal 1, called_texts.size
    assert_match "Cheetah", called_texts.first
    assert_equal "old-model", lion.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", cheetah.reload.embedding_model
  end

  test "perform with only_missing: false regenerates all organisms" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    lion = Species.create!(biome: biome, name: "Lion", description: "Apex felid.")

    org1 = Organism.create!(
      species: lion,
      name: "Alpha Male",
      description: "Dominant pride leader.",
      themes: [ "leader" ],
      embedding: Array.new(1024, 0.1),
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    org2 = Organism.create!(
      species: lion,
      name: "Hunter Female",
      description: "Primary hunter.",
      themes: [ "hunter" ],
      embedding: Array.new(1024, 0.1),
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )

    new_vector = Array.new(1024, 0.3)
    called_texts = []

    with_stubbed_generator(->(text) {
      called_texts << text
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("Organism", only_missing: false)
      end
    end

    assert_equal 2, called_texts.size
    assert_equal "qwen3-embedding:0.6b", org1.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", org2.reload.embedding_model
  end

  test "perform handles individual embedding failures gracefully and reports failure counts" do
    biome = Biome.create!(name: "Savanna", description: "Grasslands.")
    Species.create!(biome: biome, name: "Lion", description: "Apex felid.")

    with_stubbed_generator(->(_text) { raise "Ollama embedding timeout" }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 2) do
        assert_nothing_raised do
          GenerateAllEmbeddingsJob.perform_now("Species", only_missing: true)
        end
      end
    end
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
