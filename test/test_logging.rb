# frozen_string_literal: true

require "test_helper"

class TestLogging < Minitest::Test
  def teardown
    RerankerRuby::Logging.clear_callbacks
  end

  def test_instrument_returns_result
    result = RerankerRuby::Logging.instrument(
      reranker_class: "TestReranker",
      query: "test",
      document_count: 5,
      top_k: 3
    ) { [1, 2, 3] }

    assert_equal [1, 2, 3], result
  end

  def test_instrument_measures_duration
    events = []
    RerankerRuby::Logging.on_rerank { |e| events << e }

    RerankerRuby::Logging.instrument(
      reranker_class: "TestReranker",
      query: "test",
      document_count: 5,
      top_k: 3
    ) { sleep(0.01); [] }

    assert_equal 1, events.length
    assert events[0][:duration_ms] >= 10
  end

  def test_callback_receives_event
    events = []
    RerankerRuby::Logging.on_rerank { |e| events << e }

    results = [
      RerankerRuby::Result.new(text: "hi", score: 0.95, index: 0)
    ]

    RerankerRuby::Logging.instrument(
      reranker_class: "RerankerRuby::Cohere",
      query: "test query",
      document_count: 10,
      top_k: 5
    ) { results }

    event = events.first
    assert_equal "RerankerRuby::Cohere", event[:reranker]
    assert_equal "test query", event[:query]
    assert_equal 10, event[:document_count]
    assert_equal 5, event[:top_k]
    assert_equal 1, event[:result_count]
    assert_in_delta 0.95, event[:top_score]
  end

  def test_multiple_callbacks
    counts = { a: 0, b: 0 }
    RerankerRuby::Logging.on_rerank { counts[:a] += 1 }
    RerankerRuby::Logging.on_rerank { counts[:b] += 1 }

    RerankerRuby::Logging.instrument(
      reranker_class: "Test", query: "q", document_count: 1, top_k: 1
    ) { [] }

    assert_equal 1, counts[:a]
    assert_equal 1, counts[:b]
  end

  def test_clear_callbacks
    called = false
    RerankerRuby::Logging.on_rerank { called = true }
    RerankerRuby::Logging.clear_callbacks

    RerankerRuby::Logging.instrument(
      reranker_class: "Test", query: "q", document_count: 1, top_k: 1
    ) { [] }

    refute called
  end

  def test_cohere_reranker_emits_event
    events = []
    RerankerRuby::Logging.on_rerank { |e| events << e }

    reranker = RerankerRuby::Cohere.new(api_key: "test-key")
    stub_request(:post, RerankerRuby::Cohere::API_URL)
      .to_return(
        status: 200,
        body: JSON.generate({
          "results" => [{ "index" => 0, "relevance_score" => 0.9 }]
        }),
        headers: { "Content-Type" => "application/json" }
      )

    reranker.rerank("test", ["doc1"], top_k: 1)

    assert_equal 1, events.length
    assert_equal "RerankerRuby::Cohere", events[0][:reranker]
    assert_equal 1, events[0][:document_count]
  end
end
