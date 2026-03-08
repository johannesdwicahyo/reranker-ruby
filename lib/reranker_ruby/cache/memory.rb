# frozen_string_literal: true

module RerankerRuby
  module Cache
    class Memory
      def initialize(ttl: 3600)
        @ttl = ttl
        @store = {}
      end

      def get(key)
        entry = @store[key]
        return nil unless entry

        if Time.now.to_f - entry[:time] > @ttl
          @store.delete(key)
          return nil
        end

        entry[:value]
      end

      def set(key, value)
        @store[key] = { value: value, time: Time.now.to_f }
      end

      def clear
        @store.clear
      end

      def size
        @store.size
      end
    end
  end
end
