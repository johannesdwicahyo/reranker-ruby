# frozen_string_literal: true

module RerankerRuby
  module Cache
    class Memory
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
    end
  end
end
