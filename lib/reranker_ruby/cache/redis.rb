# frozen_string_literal: true

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

        Marshal.load(data) # rubocop:disable Security/MarshalLoad
      end

      def set(key, value)
        @redis.setex("#{@prefix}#{key}", @ttl, Marshal.dump(value))
      end

      def clear
        keys = @redis.keys("#{@prefix}*")
        @redis.del(*keys) if keys.any?
      end
    end
  end
end
