# frozen_string_literal: true

require "test_helper"

class TestJina < Minitest::Test
  def setup
    @reranker = RerankerRuby::Jina.new(api_key: "test-key")
    @query = "What is the capital of France?"
    @documents = [
      "Berlin is the capital of Germany.",
      "Paris is the capital and largest city of France.",
      "Lyon is the second-largest city in France."
    ]
  end

  def test_rerank_with_strings
    stub_jina_api([
      { "index" => 1, "relevance_score" => 0.98 },
      { "index" => 2, "relevance_score" => 0.55 },
      { "index" => 0, "relevance_score" => 0.10 }
    ])

    results = @reranker.rerank(@query, @documents, top_k: 3)

    assert_equal 3, results.length
    assert_equal "Paris is the capital and largest city of France.", results[0].text
    assert_in_delta 0.98, results[0].score
  end

  def test_rerank_with_hash_documents
    docs = [
      { text: "Berlin is the capital.", source: "wiki" },
      { text: "Paris is the capital of France.", source: "encyclopedia" }
    ]

    stub_jina_api([
      { "index" => 1, "relevance_score" => 0.99 },
      { "index" => 0, "relevance_score" => 0.10 }
    ])

    results = @reranker.rerank(@query, docs, top_k: 2)

    assert_equal({ source: "encyclopedia" }, results[0].metadata)
  end

  def test_api_error
    stub_request(:post, RerankerRuby::Jina::API_URL)
      .to_return(status: 500, body: '{"detail":"internal error"}')

    assert_raises(RerankerRuby::APIError) do
      @reranker.rerank(@query, @documents)
    end
  end

  def test_sends_documents_as_objects
    stub_jina_api([])

    @reranker.rerank(@query, @documents)

    assert_requested(:post, RerankerRuby::Jina::API_URL) do |req|
      body = JSON.parse(req.body)
      body["documents"].all? { |d| d.key?("text") }
    end
  end

  private

  def stub_jina_api(results)
    stub_request(:post, RerankerRuby::Jina::API_URL)
      .to_return(
        status: 200,
        body: JSON.generate({ "model" => "test", "results" => results }),
        headers: { "Content-Type" => "application/json" }
      )
  end
end
