# frozen_string_literal: true

require "test_helper"

class TestScoreNormalizer < Minitest::Test
  def setup
    @results = [
      RerankerRuby::Result.new(text: "a", score: 10.0, index: 0),
      RerankerRuby::Result.new(text: "b", score: 5.0, index: 1),
      RerankerRuby::Result.new(text: "c", score: 1.0, index: 2)
    ]
  end

  def test_min_max
    normalized = RerankerRuby::ScoreNormalizer.min_max(@results)

    assert_in_delta 1.0, normalized[0].score
    assert_in_delta 0.0, normalized[2].score
    assert normalized[1].score > 0.0 && normalized[1].score < 1.0
  end

  def test_min_max_preserves_text_and_index
    normalized = RerankerRuby::ScoreNormalizer.min_max(@results)

    assert_equal "a", normalized[0].text
    assert_equal 0, normalized[0].index
  end

  def test_min_max_identical_scores
    results = [
      RerankerRuby::Result.new(text: "a", score: 5.0, index: 0),
      RerankerRuby::Result.new(text: "b", score: 5.0, index: 1)
    ]

    normalized = RerankerRuby::ScoreNormalizer.min_max(results)

    assert_in_delta 1.0, normalized[0].score
    assert_in_delta 1.0, normalized[1].score
  end

  def test_min_max_empty
    assert_equal [], RerankerRuby::ScoreNormalizer.min_max([])
  end

  def test_softmax
    normalized = RerankerRuby::ScoreNormalizer.softmax(@results)

    total = normalized.sum(&:score)
    assert_in_delta 1.0, total

    # Order preserved: highest raw score gets highest softmax
    assert normalized[0].score > normalized[1].score
    assert normalized[1].score > normalized[2].score
  end

  def test_softmax_empty
    assert_equal [], RerankerRuby::ScoreNormalizer.softmax([])
  end

  def test_sigmoid
    normalized = RerankerRuby::ScoreNormalizer.sigmoid(@results)

    normalized.each do |r|
      assert r.score >= 0.0 && r.score <= 1.0, "Score #{r.score} not in [0,1]"
    end

    # Order preserved
    assert normalized[0].score > normalized[1].score
  end

  def test_sigmoid_zero_input
    results = [RerankerRuby::Result.new(text: "x", score: 0.0, index: 0)]
    normalized = RerankerRuby::ScoreNormalizer.sigmoid(results)
    assert_in_delta 0.5, normalized[0].score
  end
end
