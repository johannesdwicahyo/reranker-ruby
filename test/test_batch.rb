# frozen_string_literal: true

require "test_helper"

class TestBatch < Minitest::Test
  def setup
    @documents = ["Paris is the capital of France.", "Berlin is the capital of Germany."]
  end

  def test_batch_rerank_single_thread
    reranker = build_mock_reranker

    queries = ["capital of France?", "capital of Germany?"]
    results = RerankerRuby::Batch.rerank(reranker, queries, @documents, top_k: 2, threads: 1)

    assert_equal 2, results.length
    assert_equal 2, results[0].length
    assert_equal 2, results[1].length
  end

  def test_batch_rerank_multithreaded
    reranker = build_mock_reranker

    queries = ["q1", "q2", "q3", "q4"]
    results = RerankerRuby::Batch.rerank(reranker, queries, @documents, top_k: 2, threads: 2)

    assert_equal 4, results.length
    results.each { |r| assert_equal 2, r.length }
  end

  def test_batch_preserves_query_order
    call_order = []
    reranker = build_tracking_reranker(call_order)

    queries = ["first", "second", "third"]
    results = RerankerRuby::Batch.rerank(reranker, queries, @documents, top_k: 2, threads: 1)

    # With single thread, should process in order
    assert_equal %w[first second third], call_order
    assert_equal 3, results.length
  end

  def test_batch_empty_queries
    reranker = build_mock_reranker
    results = RerankerRuby::Batch.rerank(reranker, [], @documents, top_k: 2)
    assert_equal [], results
  end

  private

  def build_mock_reranker
    cohere = RerankerRuby::Cohere.new(api_key: "test")
    stub_request(:post, RerankerRuby::Cohere::API_URL)
      .to_return(
        status: 200,
        body: JSON.generate({
          "results" => [
            { "index" => 0, "relevance_score" => 0.9 },
            { "index" => 1, "relevance_score" => 0.5 }
          ]
        }),
        headers: { "Content-Type" => "application/json" }
      )
    cohere
  end

  def build_tracking_reranker(call_order)
    klass = Class.new(RerankerRuby::Base) do
      define_method(:rerank) do |query, documents, top_k: 10|
        call_order << query
        documents.each_with_index.map do |d, i|
          text = d.is_a?(Hash) ? d[:text] : d.to_s
          RerankerRuby::Result.new(text: text, score: 1.0 - i * 0.1, index: i)
        end.first(top_k)
      end
    end
    klass.new
  end
end
