# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module RerankerRuby
  class Error < StandardError; end
  class APIError < Error; end

  class Base
    def initialize(api_key: nil, cache: nil)
      @api_key = api_key
      @cache = cache
    end

    def rerank(query, documents, top_k: 10)
      raise NotImplementedError, "#{self.class}#rerank must be implemented"
    end

    private

    def instrument(query:, document_count:, top_k:, &block)
      Logging.instrument(
        reranker_class: self.class.name,
        query: query,
        document_count: document_count,
        top_k: top_k,
        &block
      )
    end

    def extract_texts(documents)
      documents.map { |d| d.is_a?(Hash) ? d[:text] || d["text"] : d.to_s }
    end

    def extract_metadata(document)
      return {} unless document.is_a?(Hash)

      document.reject { |k, _| k == :text || k == "text" }
    end

    def cache_key(query, documents)
      require "digest"
      Digest::SHA256.hexdigest("#{query}:#{documents.map(&:to_s).join("|")}")
    end

    def with_cache(query, documents, &block)
      return yield unless @cache

      key = cache_key(query, documents)
      cached = @cache.get(key)
      return cached if cached

      result = yield
      @cache.set(key, result)
      result
    end

    def post(url, body, headers: {})
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      headers.each { |k, v| request[k] = v }
      request.body = JSON.generate(body)

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise APIError, "HTTP #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    end
  end
end
