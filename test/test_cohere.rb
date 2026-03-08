# frozen_string_literal: true

require "test_helper"

class TestCohere < Minitest::Test
  def setup
    @reranker = RerankerRuby::Cohere.new(api_key: "test-key")
    @query = "What is the capital of France?"
    @documents = [
      "Berlin is the capital of Germany.",
      "Paris is the capital and largest city of France.",
      "Lyon is the second-largest city in France."
    ]
  end

  def test_rerank_with_strings
    stub_cohere_api([
      { "index" => 1, "relevance_score" => 0.99 },
      { "index" => 2, "relevance_score" => 0.61 },
      { "index" => 0, "relevance_score" => 0.12 }
    ])

    results = @reranker.rerank(@query, @documents, top_k: 3)

    assert_equal 3, results.length
    assert_equal "Paris is the capital and largest city of France.", results[0].text
    assert_in_delta 0.99, results[0].score
    assert_equal 1, results[0].index
  end

  def test_rerank_with_hash_documents
    docs = [
      { text: "Berlin is the capital of Germany.", source: "wiki", id: "d1" },
      { text: "Paris is the capital of France.", source: "wiki", id: "d2" }
    ]

    stub_cohere_api([
      { "index" => 1, "relevance_score" => 0.99 },
      { "index" => 0, "relevance_score" => 0.12 }
    ])

    results = @reranker.rerank(@query, docs, top_k: 2)

    assert_equal 2, results.length
    assert_equal({ source: "wiki", id: "d2" }, results[0].metadata)
  end

  def test_rerank_sorted_by_score
    stub_cohere_api([
      { "index" => 0, "relevance_score" => 0.12 },
      { "index" => 1, "relevance_score" => 0.99 },
      { "index" => 2, "relevance_score" => 0.61 }
    ])

    results = @reranker.rerank(@query, @documents, top_k: 3)

    scores = results.map(&:score)
    assert_equal scores, scores.sort.reverse
  end

  def test_api_error
    stub_request(:post, RerankerRuby::Cohere::API_URL)
      .to_return(status: 401, body: '{"message":"invalid api key"}')

    assert_raises(RerankerRuby::APIError) do
      @reranker.rerank(@query, @documents)
    end
  end

  def test_sends_correct_headers
    stub_cohere_api([])

    @reranker.rerank(@query, @documents)

    assert_requested(:post, RerankerRuby::Cohere::API_URL,
      headers: { "Authorization" => "Bearer test-key", "Content-Type" => "application/json" })
  end

  private

  def stub_cohere_api(results)
    stub_request(:post, RerankerRuby::Cohere::API_URL)
      .to_return(
        status: 200,
        body: JSON.generate({ "id" => "test", "results" => results }),
        headers: { "Content-Type" => "application/json" }
      )
  end
end
