# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "digest"

module RerankerRuby
  class Error < StandardError; end
  class APIError < Error; end
  class TimeoutError < Error; end
  class RateLimitError < APIError; end
  class ValidationError < Error; end

  class Base
    def initialize(api_key: nil, cache: nil, timeout: nil, max_retries: nil)
      @api_key = api_key
      @cache = cache
      @timeout = timeout || 30
      @max_retries = max_retries || 3
      @connections = {}
      @conn_mutex = Mutex.new
    end

    def rerank(query, documents, top_k: 10)
      raise NotImplementedError, "#{self.class}#rerank must be implemented"
    end

    private

    def validate_inputs!(query, documents, top_k)
      raise ValidationError, "query cannot be nil or empty" if query.nil? || query.to_s.strip.empty?
      raise ValidationError, "documents cannot be nil or empty" if documents.nil? || documents.empty?
      raise ValidationError, "top_k must be positive" if top_k && top_k <= 0
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

    def get_connection(uri)
      host_key = "#{uri.host}:#{uri.port}"
      @conn_mutex.synchronize do
        conn = @connections[host_key]
        if conn && conn.started?
          return conn
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        http.write_timeout = @timeout
        http.keep_alive_timeout = 30
        http.start
        @connections[host_key] = http
        http
      end
    end

    def post(url, body, headers: {})
      uri = URI.parse(url)
      retries = 0

      begin
        http = get_connection(uri)
        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "RerankerRuby/#{RerankerRuby::VERSION}"
        headers.each { |k, v| request[k] = v }
        request.body = JSON.generate(body)

        response = http.request(request)

        if response.code.to_i == 429
          retry_after = response["Retry-After"]&.to_f || (2 ** retries)
          raise RateLimitError, "Rate limited (429). Retry after #{retry_after}s"
        end

        if response.code.to_i >= 500
          raise APIError, "HTTP #{response.code}: #{response.body}"
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise APIError, "HTTP #{response.code}: #{response.body}"
        end

        JSON.parse(response.body)
      rescue RateLimitError, APIError => e
        retries += 1
        if retries <= @max_retries
          wait = if e.is_a?(RateLimitError) && e.message =~ /after ([\d.]+)s/
                   $1.to_f
                 else
                   2 ** (retries - 1)
                 end
          sleep(wait)
          retry
        end
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
        # Reset pooled connection on network errors
        @conn_mutex.synchronize { @connections.delete("#{uri.host}:#{uri.port}") }
        retries += 1
        if retries <= @max_retries
          sleep(2 ** (retries - 1))
          retry
        end
        raise TimeoutError, "Request failed after #{@max_retries} retries: #{e.message}"
      rescue JSON::ParserError => e
        raise APIError, "Invalid JSON response: #{e.message}"
      end
    end
  end
end
