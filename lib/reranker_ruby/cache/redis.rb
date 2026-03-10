# frozen_string_literal: true

require "json"

module RerankerRuby
  module Cache
    class Redis
      def initialize(redis:, ttl: 3600, prefix: "reranker:")
        @redis = redis
        @ttl = ttl
        @prefix = prefix
      end

      def get(key)
        data = @redis.get("#{@prefix}#{key}")
        return nil unless data

        parsed = JSON.parse(data)
        parsed.map do |h|
          Result.new(
            text: h["text"],
            score: h["score"],
            index: h["index"],
            metadata: h["metadata"] || {}
          )
        end
      end

      def set(key, value)
        serialized = JSON.generate(value.map(&:to_h))
        @redis.setex("#{@prefix}#{key}", @ttl, serialized)
      end

      def clear
        keys = @redis.keys("#{@prefix}*")
        @redis.del(*keys) if keys.any?
      end
    end
  end
end
