# frozen_string_literal: true

require "test_helper"

class TestMemoryCache < Minitest::Test
  def setup
    @cache = RerankerRuby::Cache::Memory.new(ttl: 2)
  end

  def test_set_and_get
    @cache.set("key1", "value1")
    assert_equal "value1", @cache.get("key1")
  end

  def test_cache_miss
    assert_nil @cache.get("nonexistent")
  end

  def test_ttl_expiry
    @cache = RerankerRuby::Cache::Memory.new(ttl: 0)
    @cache.set("key1", "value1")
    sleep 0.01
    assert_nil @cache.get("key1")
  end

  def test_clear
    @cache.set("key1", "value1")
    @cache.set("key2", "value2")
    @cache.clear
    assert_nil @cache.get("key1")
    assert_nil @cache.get("key2")
  end

  def test_size
    assert_equal 0, @cache.size
    @cache.set("key1", "value1")
    assert_equal 1, @cache.size
  end

  def test_overwrite
    @cache.set("key1", "old")
    @cache.set("key1", "new")
    assert_equal "new", @cache.get("key1")
  end
end

class TestCachedReranker < Minitest::Test
  def test_cohere_with_cache
    cache = RerankerRuby::Cache::Memory.new(ttl: 3600)
    reranker = RerankerRuby::Cohere.new(api_key: "test-key", cache: cache)

    query = "test query"
    docs = ["doc1", "doc2"]

    stub_request(:post, RerankerRuby::Cohere::API_URL)
      .to_return(
        status: 200,
        body: JSON.generate({ "results" => [
          { "index" => 0, "relevance_score" => 0.9 },
          { "index" => 1, "relevance_score" => 0.5 }
        ] }),
        headers: { "Content-Type" => "application/json" }
      )

    # First call hits API
    results1 = reranker.rerank(query, docs)
    assert_equal 2, results1.length

    # Second call should use cache (no additional API request)
    results2 = reranker.rerank(query, docs)
    assert_equal 2, results2.length

    # Only one API call should have been made
    assert_requested(:post, RerankerRuby::Cohere::API_URL, times: 1)
  end
end
