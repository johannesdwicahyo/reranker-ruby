# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "digest"

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

    def validate_inputs!(query, documents, top_k)
      raise ArgumentError, "query cannot be nil or empty" if query.nil? || query.to_s.strip.empty?
      raise ArgumentError, "documents cannot be nil or empty" if documents.nil? || documents.empty?
      raise ArgumentError, "top_k must be positive" if top_k && top_k <= 0
    end

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

    def cache_key(query, documents, top_k = nil)
      Digest::SHA256.hexdigest("#{query}:#{top_k}:#{documents.map(&:to_s).join("|")}")
    end

    def with_cache(query, documents, top_k: nil, &block)
      return yield unless @cache

      key = cache_key(query, documents, top_k)
      cached = @cache.get(key)
      return cached if cached

      result = yield
      @cache.set(key, result)
      result
    end

    def post(url, body, headers: {})
      uri = URI.parse(url)
      retries = 0
      max_retries = 3

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 30
        http.read_timeout = 30
        http.write_timeout = 30

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "RerankerRuby/#{RerankerRuby::VERSION}"
        headers.each { |k, v| request[k] = v }
        request.body = JSON.generate(body)

        response = http.request(request)

        if response.code.to_i == 429 || response.code.to_i >= 500
          raise APIError, "HTTP #{response.code}: #{response.body}"
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise APIError, "HTTP #{response.code}: #{response.body}"
        end

        JSON.parse(response.body)
      rescue APIError => e
        retries += 1
        if retries <= max_retries && (e.message.include?("429") || e.message.include?("50"))
          sleep(2 ** (retries - 1))
          retry
        end
        raise
      rescue JSON::ParserError => e
        raise APIError, "Invalid JSON response: #{e.message}"
      end
    end
  end
end
