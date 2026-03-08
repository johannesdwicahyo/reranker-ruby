# frozen_string_literal: true

require "test_helper"

class TestConfiguration < Minitest::Test
  def teardown
    RerankerRuby.reset_configuration!
  end

  def test_default_configuration
    config = RerankerRuby.configuration
    assert_equal :cohere, config.default_provider
    assert_equal 10, config.default_top_k
    assert_equal 3600, config.cache_ttl
    assert_nil config.cohere_api_key
    assert_nil config.jina_api_key
    assert_nil config.cache_store
  end

  def test_configure_block
    RerankerRuby.configure do |config|
      config.default_provider = :jina
      config.jina_api_key = "test-key"
      config.default_top_k = 5
    end

    assert_equal :jina, RerankerRuby.configuration.default_provider
    assert_equal "test-key", RerankerRuby.configuration.jina_api_key
    assert_equal 5, RerankerRuby.configuration.default_top_k
  end

  def test_build_cohere_reranker
    RerankerRuby.configure do |config|
      config.default_provider = :cohere
      config.cohere_api_key = "cohere-key"
    end

    reranker = RerankerRuby.configuration.build_reranker
    assert_instance_of RerankerRuby::Cohere, reranker
  end

  def test_build_jina_reranker
    RerankerRuby.configure do |config|
      config.default_provider = :jina
      config.jina_api_key = "jina-key"
    end

    reranker = RerankerRuby.configuration.build_reranker
    assert_instance_of RerankerRuby::Jina, reranker
  end

  def test_build_cohere_without_key_raises
    RerankerRuby.configure do |config|
      config.default_provider = :cohere
      config.cohere_api_key = nil
    end

    assert_raises(RerankerRuby::Error) do
      RerankerRuby.configuration.build_reranker
    end
  end

  def test_build_jina_without_key_raises
    RerankerRuby.configure do |config|
      config.default_provider = :jina
      config.jina_api_key = nil
    end

    assert_raises(RerankerRuby::Error) do
      RerankerRuby.configuration.build_reranker
    end
  end

  def test_unknown_provider_raises
    RerankerRuby.configure do |config|
      config.default_provider = :unknown
    end

    assert_raises(RerankerRuby::Error) do
      RerankerRuby.configuration.build_reranker
    end
  end

  def test_build_with_memory_cache
    RerankerRuby.configure do |config|
      config.default_provider = :cohere
      config.cohere_api_key = "key"
      config.cache_store = :memory
      config.cache_ttl = 600
    end

    reranker = RerankerRuby.configuration.build_reranker
    assert_instance_of RerankerRuby::Cohere, reranker
  end

  def test_reset_configuration
    RerankerRuby.configure { |c| c.default_provider = :jina }
    RerankerRuby.reset_configuration!
    assert_equal :cohere, RerankerRuby.configuration.default_provider
  end

  def test_global_reranker
    RerankerRuby.configure do |config|
      config.default_provider = :cohere
      config.cohere_api_key = "key"
    end

    reranker = RerankerRuby.reranker
    assert_instance_of RerankerRuby::Cohere, reranker
    # Should return same instance
    assert_same reranker, RerankerRuby.reranker
  end

  def test_convenience_rerank
    RerankerRuby.configure do |config|
      config.default_provider = :cohere
      config.cohere_api_key = "key"
      config.default_top_k = 2
    end

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

    results = RerankerRuby.rerank("test", ["doc1", "doc2"])
    assert_equal 2, results.length
  end
end
