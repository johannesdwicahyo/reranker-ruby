# frozen_string_literal: true

require "test_helper"

# A simple mock reranker that returns predetermined scores
class MockReranker < RerankerRuby::Base
  def initialize(scores)
    super()
    @scores = scores
  end

  def rerank(query, documents, top_k: 10)
    texts = documents.map { |d| d.is_a?(Hash) ? d[:text] || d["text"] : d.to_s }
    texts.each_with_index.map do |text, idx|
      RerankerRuby::Result.new(
        text: text,
        score: @scores[idx] || 0.0,
        index: idx,
        metadata: {}
      )
    end.sort.first(top_k)
  end
end

class TestEnsemble < Minitest::Test
  def test_combines_two_rerankers
    reranker_a = MockReranker.new([0.9, 0.1, 0.5])
    reranker_b = MockReranker.new([0.2, 0.8, 0.6])

    ensemble = RerankerRuby::Ensemble.new(
      rerankers: [reranker_a, reranker_b],
      normalize: :none
    )

    results = ensemble.rerank("test", ["doc1", "doc2", "doc3"], top_k: 3)

    assert_equal 3, results.length
    # Scores should be averaged: doc1=(0.9+0.2)/2=0.55, doc2=(0.1+0.8)/2=0.45, doc3=(0.5+0.6)/2=0.55
    scores = results.map(&:score)
    assert_equal scores, scores.sort.reverse
  end

  def test_weighted_ensemble
    reranker_a = MockReranker.new([0.9, 0.1])
    reranker_b = MockReranker.new([0.1, 0.9])

    # Heavy weight on reranker_a
    ensemble = RerankerRuby::Ensemble.new(
      rerankers: [reranker_a, reranker_b],
      weights: [0.8, 0.2],
      normalize: :none
    )

    results = ensemble.rerank("test", ["doc1", "doc2"], top_k: 2)

    # doc1: 0.9*0.8 + 0.1*0.2 = 0.74
    # doc2: 0.1*0.8 + 0.9*0.2 = 0.26
    assert_equal "doc1", results[0].text
    assert_in_delta 0.74, results[0].score, 0.01
  end

  def test_with_min_max_normalization
    reranker_a = MockReranker.new([100.0, 50.0, 10.0])
    reranker_b = MockReranker.new([0.9, 0.5, 0.1])

    ensemble = RerankerRuby::Ensemble.new(
      rerankers: [reranker_a, reranker_b],
      normalize: :min_max
    )

    results = ensemble.rerank("test", ["doc1", "doc2", "doc3"], top_k: 3)

    # After min-max, both rerankers agree doc1 is best
    assert_equal "doc1", results[0].text
  end

  def test_top_k_limiting
    reranker_a = MockReranker.new([0.9, 0.8, 0.7, 0.6, 0.5])

    ensemble = RerankerRuby::Ensemble.new(rerankers: [reranker_a], normalize: :none)
    results = ensemble.rerank("test", %w[a b c d e], top_k: 2)

    assert_equal 2, results.length
  end

  def test_mismatched_weights_raises
    assert_raises(ArgumentError) do
      RerankerRuby::Ensemble.new(
        rerankers: [MockReranker.new([]), MockReranker.new([])],
        weights: [0.5]
      )
    end
  end

  def test_preserves_metadata
    reranker = MockReranker.new([0.9, 0.5])

    ensemble = RerankerRuby::Ensemble.new(rerankers: [reranker], normalize: :none)
    docs = [
      { text: "doc1", source: "wiki" },
      { text: "doc2", source: "arxiv" }
    ]

    results = ensemble.rerank("test", docs, top_k: 2)

    assert results.any? { |r| r.metadata[:source] == "wiki" }
  end
end
