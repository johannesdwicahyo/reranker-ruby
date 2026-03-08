# frozen_string_literal: true

require "test_helper"

class TestResult < Minitest::Test
  def test_basic_attributes
    result = RerankerRuby::Result.new(text: "hello", score: 0.95, index: 0)
    assert_equal "hello", result.text
    assert_in_delta 0.95, result.score
    assert_equal 0, result.index
    assert_equal({}, result.metadata)
  end

  def test_with_metadata
    result = RerankerRuby::Result.new(text: "hello", score: 0.9, index: 1, metadata: { source: "wiki" })
    assert_equal({ source: "wiki" }, result.metadata)
  end

  def test_sorting
    results = [
      RerankerRuby::Result.new(text: "low", score: 0.1, index: 0),
      RerankerRuby::Result.new(text: "high", score: 0.9, index: 1),
      RerankerRuby::Result.new(text: "mid", score: 0.5, index: 2)
    ]
    sorted = results.sort
    assert_equal "high", sorted[0].text
    assert_equal "mid", sorted[1].text
    assert_equal "low", sorted[2].text
  end

  def test_to_h
    result = RerankerRuby::Result.new(text: "hello", score: 0.9, index: 0, metadata: { id: 1 })
    h = result.to_h
    assert_equal "hello", h[:text]
    assert_in_delta 0.9, h[:score]
    assert_equal 0, h[:index]
    assert_equal({ id: 1 }, h[:metadata])
  end
end
