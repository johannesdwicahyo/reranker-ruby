# frozen_string_literal: true

module RerankerRuby
  module Cache
    class Memory
      attr_reader :ttl

      def initialize(ttl: 3600)
        @ttl = ttl
        @store = {}
        @mutex = Mutex.new
      end

      def get(key)
        @mutex.synchronize do
          entry = @store[key]
          return nil unless entry

          if Time.now.to_f - entry[:time] > @ttl
            @store.delete(key)
            return nil
          end

          entry[:value]
        end
      end

      def set(key, value)
        @mutex.synchronize do
          @store[key] = { value: value, time: Time.now.to_f }
        end
      end

      def invalidate(key)
        @mutex.synchronize do
          @store.delete(key)
        end
      end

      def invalidate_matching(pattern)
        @mutex.synchronize do
          @store.delete_if { |k, _| k.match?(pattern) }
        end
      end

      def clear
        @mutex.synchronize do
          @store.clear
        end
      end

      def size
        @mutex.synchronize do
          @store.size
        end
      end

      def prune_expired
        @mutex.synchronize do
          now = Time.now.to_f
          @store.delete_if { |_, entry| now - entry[:time] > @ttl }
        end
      end
    end
  end
end
