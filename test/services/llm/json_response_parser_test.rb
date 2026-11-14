# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Llm::JsonResponseParserTest < ActiveSupport::TestCase
  test "extract_list prefers response.parsed when present" do
    response = OpenStruct.new(parsed: { "species" => [ { "name" => "Lion" } ] }, content: "ignored")
    assert_equal [ { "name" => "Lion" } ], Llm::JsonResponseParser.extract_list(response, key: "species")
  end

  test "extract_list strips think tags and markdown fences" do
    response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Thinking about species...</think>
        ```json
        { "species": [{ "name": "Cheetah", "themes": ["cursorial"] }] }
        ```
      TEXT
    )

    assert_equal [ { "name" => "Cheetah", "themes" => [ "cursorial" ] } ],
                 Llm::JsonResponseParser.extract_list(response, key: "species")
  end

  test "extract_list falls back to embedded JSON and returns empty array for invalid text" do
    embedded_array = OpenStruct.new(parsed: nil, content: "Here is the list: [{\"name\":\"Orca\"}] Hope that helps!")
    assert_equal [ { "name" => "Orca" } ], Llm::JsonResponseParser.extract_list(embedded_array, key: "species")

    embedded_object = OpenStruct.new(parsed: nil, content: "[Note] {\"species\":[{\"name\":\"Blue Whale\"}]} Done.")
    assert_equal [ { "name" => "Blue Whale" } ], Llm::JsonResponseParser.extract_list(embedded_object, key: "species")

    invalid = OpenStruct.new(parsed: nil, content: "Not JSON at all")
    assert_equal [], Llm::JsonResponseParser.extract_list(invalid, key: "species")
  end

  test "extract_hash parses flat JSON objects and unwraps optional nested key" do
    flat = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Analyzing biological themes...</think>
        ```json
        {
          "Trophic Role": "Apex carnivore regulating prey population.",
          "Niche Specialization": "Pursuit hunting in open grassland biome."
        }
        ```
      TEXT
    )

    assert_equal(
      { "Trophic Role" => "Apex carnivore regulating prey population.", "Niche Specialization" => "Pursuit hunting in open grassland biome." },
      Llm::JsonResponseParser.extract_hash(flat)
    )

    wrapped = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        ```json
        {
          "themes": {
            "Adaptation": "Blubber insulation against arctic waters."
          }
        }
        ```
      TEXT
    )

    assert_equal(
      { "Adaptation" => "Blubber insulation against arctic waters." },
      Llm::JsonResponseParser.extract_hash(wrapped, key: "themes")
    )
  end
end
