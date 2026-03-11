# frozen_string_literal: true

module RerankerRuby
  class Configuration
    attr_accessor :default_provider, :cohere_api_key, :jina_api_key, :voyage_api_key,
                  :default_model, :default_top_k, :cache_store, :cache_ttl,
                  :logger, :onnx_model, :onnx_model_path, :onnx_cache_dir,
                  :timeout, :max_retries

    def initialize
      @default_provider = :cohere
      @cohere_api_key = nil
      @jina_api_key = nil
      @voyage_api_key = nil
      @default_model = nil
      @default_top_k = 10
      @cache_store = nil
      @cache_ttl = 3600
      @logger = nil
      @onnx_model = nil
      @onnx_model_path = nil
      @onnx_cache_dir = nil
      @timeout = 30
      @max_retries = 3
    end

    # Build a reranker instance from configuration
    def build_reranker
      cache = build_cache

      case default_provider
      when :cohere
        raise Error, "cohere_api_key is required" unless cohere_api_key
        opts = { api_key: cohere_api_key, cache: cache }
        opts[:model] = default_model if default_model
        Cohere.new(**opts)
      when :jina
        raise Error, "jina_api_key is required" unless jina_api_key
        opts = { api_key: jina_api_key, cache: cache }
        opts[:model] = default_model if default_model
        Jina.new(**opts)
      when :voyage
        raise Error, "voyage_api_key is required" unless voyage_api_key
        opts = { api_key: voyage_api_key, cache: cache, timeout: timeout, max_retries: max_retries }
        opts[:model] = default_model if default_model
        Voyage.new(**opts)
      when :onnx
        opts = { cache: cache }
        opts[:model] = onnx_model if onnx_model
        opts[:model_path] = onnx_model_path if onnx_model_path
        opts[:cache_dir] = onnx_cache_dir if onnx_cache_dir
        Onnx.new(**opts)
      else
        raise Error, "Unknown provider: #{default_provider}"
      end
    end

    private

    def build_cache
      case cache_store
      when :memory
        Cache::Memory.new(ttl: cache_ttl)
      when :redis
        require "redis"
        Cache::Redis.new(redis: ::Redis.new, ttl: cache_ttl)
      when nil
        nil
      else
        # Allow passing a pre-built cache instance
        cache_store
      end
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
      @reranker = nil
    end

    # Global reranker instance built from configuration
    def reranker
      @reranker ||= configuration.build_reranker
    end

    # Convenience method for quick reranking
    def rerank(query, documents, top_k: nil)
      top_k ||= configuration.default_top_k
      reranker.rerank(query, documents, top_k: top_k)
    end
  end
end
