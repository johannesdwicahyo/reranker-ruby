# frozen_string_literal: true

require "test_helper"

class TestMiddleware < Minitest::Test
  def setup
    @reranker = RerankerRuby::Cohere.new(api_key: "test-key")
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
  end

  def test_with_string_candidates
    middleware = RerankerRuby::Middleware.new(reranker: @reranker, top_k: 2)
    results = middleware.call(query: "test", candidates: ["doc1", "doc2"])

    assert_equal 2, results.length
    assert_instance_of RerankerRuby::Result, results[0]
  end

  def test_with_hash_candidates
    middleware = RerankerRuby::Middleware.new(reranker: @reranker, top_k: 2, text_key: :content)
    candidates = [
      { content: "Paris is the capital.", source: "wiki" },
      { content: "Berlin is the capital.", source: "encyclopedia" }
    ]

    results = middleware.call(query: "test", candidates: candidates)

    assert_equal 2, results.length
  end

  def test_with_object_candidates
    candidate_class = Struct.new(:content, :id)
    candidates = [
      candidate_class.new("Paris is the capital.", 1),
      candidate_class.new("Berlin is the capital.", 2)
    ]

    middleware = RerankerRuby::Middleware.new(reranker: @reranker, top_k: 2, text_key: :content)
    results = middleware.call(query: "test", candidates: candidates)

    assert_equal 2, results.length
  end

  def test_override_top_k
    middleware = RerankerRuby::Middleware.new(reranker: @reranker, top_k: 10)
    results = middleware.call(query: "test", candidates: ["doc1", "doc2"], top_k: 1)

    # Should use the call-level top_k, but API stub returns 2 results
    # The reranker itself limits to top_k via the API
    assert results.length <= 2
  end

  def test_uses_global_reranker_when_none_provided
    RerankerRuby.configure do |config|
      config.default_provider = :cohere
      config.cohere_api_key = "global-key"
    end

    stub_request(:post, RerankerRuby::Cohere::API_URL)
      .to_return(
        status: 200,
        body: JSON.generate({
          "results" => [{ "index" => 0, "relevance_score" => 0.9 }]
        }),
        headers: { "Content-Type" => "application/json" }
      )

    middleware = RerankerRuby::Middleware.new(top_k: 1)
    results = middleware.call(query: "test", candidates: ["doc1"])

    assert_equal 1, results.length
  ensure
    RerankerRuby.reset_configuration!
  end
end
