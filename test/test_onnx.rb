# frozen_string_literal: true

require "test_helper"

# Mock the optional dependencies for testing
module OnnxRuntime
  class InferenceSession
    attr_reader :inputs

    def initialize(model_path)
      @model_path = model_path
      @inputs = [
        { name: "input_ids" },
        { name: "attention_mask" },
        { name: "token_type_ids" }
      ]
    end

    def run(_output_names, inputs)
      # Return a mock logit; simulate varying relevance based on input length
      ids = inputs["input_ids"][0]
      logit = ids.length * 0.1 # longer inputs = higher score for testing
      [[[logit]]]
    end
  end
end

module Tokenizers
  Encoding = Struct.new(:ids, :attention_mask, :type_ids, keyword_init: true)

  def self.from_pretrained(_model_id)
    MockTokenizer.new
  end

  def self.from_file(_path)
    MockTokenizer.new
  end

  class MockTokenizer
    def encode(text, pair = nil, add_special_tokens: true)
      # Simulate tokenization: CLS + query tokens + SEP + doc tokens + SEP
      query_tokens = text.split.length
      doc_tokens = pair ? pair.split.length : 0
      total = 1 + query_tokens + 1 + doc_tokens + 1 # CLS + query + SEP + doc + SEP

      ids = (1..total).to_a
      attention_mask = Array.new(total, 1)
      type_ids = Array.new(1 + query_tokens + 1, 0) + Array.new(doc_tokens + 1, 1)

      Encoding.new(ids: ids, attention_mask: attention_mask, type_ids: type_ids)
    end

    def enable_truncation(_max_length)
      # no-op for testing
    end
  end
end

class TestOnnx < Minitest::Test
  def setup
    # Create a fake model file path (the mock session doesn't read it)
    @model_path = File.join(Dir.tmpdir, "test_model.onnx")
    FileUtils.touch(@model_path)
  end

  def test_rerank_with_local_model
    reranker = RerankerRuby::Onnx.new(model_path: @model_path, tokenizer: "cross-encoder/ms-marco-MiniLM-L-6-v2")

    query = "What is the capital of France?"
    documents = [
      "Berlin is the capital of Germany.",
      "Paris is the capital and largest city of France.",
      "Lyon."
    ]

    results = reranker.rerank(query, documents, top_k: 3)

    assert_equal 3, results.length
    # Results should be sorted by score descending
    scores = results.map(&:score)
    assert_equal scores, scores.sort.reverse
  end

  def test_rerank_top_k
    reranker = RerankerRuby::Onnx.new(model_path: @model_path, tokenizer: "cross-encoder/ms-marco-MiniLM-L-6-v2")

    query = "test query"
    documents = ["doc1", "doc2", "doc3", "doc4", "doc5"]

    results = reranker.rerank(query, documents, top_k: 2)

    assert_equal 2, results.length
  end

  def test_rerank_preserves_metadata
    reranker = RerankerRuby::Onnx.new(model_path: @model_path, tokenizer: "cross-encoder/ms-marco-MiniLM-L-6-v2")

    query = "test"
    documents = [
      { text: "Document one", source: "wiki", id: "d1" },
      { text: "Document two", source: "arxiv", id: "d2" }
    ]

    results = reranker.rerank(query, documents, top_k: 2)

    metadata_values = results.map(&:metadata)
    assert(metadata_values.any? { |m| m[:source] == "wiki" })
    assert(metadata_values.any? { |m| m[:source] == "arxiv" })
  end

  def test_rerank_result_has_original_index
    reranker = RerankerRuby::Onnx.new(model_path: @model_path, tokenizer: "cross-encoder/ms-marco-MiniLM-L-6-v2")

    query = "test"
    documents = ["short", "a longer document with more words"]

    results = reranker.rerank(query, documents, top_k: 2)

    # The longer document should score higher (mock scores by token count)
    assert_equal 1, results[0].index
    assert_equal "a longer document with more words", results[0].text
  end

  def test_sigmoid_scores_between_0_and_1
    reranker = RerankerRuby::Onnx.new(model_path: @model_path, tokenizer: "cross-encoder/ms-marco-MiniLM-L-6-v2")

    query = "test"
    documents = ["doc1", "doc2"]

    results = reranker.rerank(query, documents, top_k: 2)

    results.each do |r|
      assert r.score >= 0.0 && r.score <= 1.0, "Score #{r.score} not in [0,1]"
    end
  end
end

class TestModelDownloader < Minitest::Test
  def test_download_caches_files
    cache_dir = File.join(Dir.tmpdir, "reranker-test-#{rand(10000)}")

    # Stub HuggingFace download requests
    stub_request(:get, %r{https://huggingface\.co/.*/resolve/main/.*})
      .to_return(status: 200, body: "fake-model-data")

    downloader = RerankerRuby::ModelDownloader.new(cache_dir: cache_dir)
    paths = downloader.download("cross-encoder/ms-marco-MiniLM-L-6-v2")

    assert File.exist?(paths[:model_path])
    assert File.exist?(paths[:tokenizer_path])

    # Second download should not make HTTP requests (files cached)
    WebMock.reset!
    stub_request(:get, %r{https://huggingface\.co/.*}).to_raise("Should not download again")

    paths2 = downloader.download("cross-encoder/ms-marco-MiniLM-L-6-v2")
    assert_equal paths[:model_path], paths2[:model_path]
  ensure
    FileUtils.rm_rf(cache_dir) if cache_dir
  end

  def test_download_follows_redirects
    cache_dir = File.join(Dir.tmpdir, "reranker-test-#{rand(10000)}")

    stub_request(:get, %r{https://huggingface\.co/.*/resolve/main/.*})
      .to_return(status: 302, headers: { "Location" => "https://cdn.huggingface.co/model.onnx" })
    stub_request(:get, "https://cdn.huggingface.co/model.onnx")
      .to_return(status: 200, body: "model-data")

    downloader = RerankerRuby::ModelDownloader.new(cache_dir: cache_dir)
    paths = downloader.download("cross-encoder/ms-marco-MiniLM-L-6-v2")

    assert File.exist?(paths[:model_path])
  ensure
    FileUtils.rm_rf(cache_dir) if cache_dir
  end
end
