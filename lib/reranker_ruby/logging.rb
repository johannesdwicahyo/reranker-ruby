# frozen_string_literal: true

require "logger"

module RerankerRuby
  # Global logging and metrics for reranking operations.
  #
  # Usage:
  #   RerankerRuby::Logging.logger = Logger.new($stdout)
  #   RerankerRuby::Logging.on_rerank do |event|
  #     puts "#{event[:reranker]} took #{event[:duration_ms]}ms for #{event[:document_count]} docs"
  #   end
  #
  module Logging
    class << self
      attr_writer :logger

      def logger
        @logger ||= Logger.new($stdout, level: Logger::WARN)
      end

      # Register a callback for rerank events
      def on_rerank(&block)
        callbacks << block
      end

      def callbacks
        @callbacks ||= []
      end

      def clear_callbacks
        @callbacks = []
      end

      # Wrap a rerank call with logging and metrics
      def instrument(reranker_class:, query:, document_count:, top_k:)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

        event = {
          reranker: reranker_class,
          query: query,
          document_count: document_count,
          top_k: top_k,
          result_count: result.length,
          duration_ms: duration_ms,
          top_score: result.first.respond_to?(:score) ? result.first.score : nil
        }

        logger.info { "[RerankerRuby] #{reranker_class} reranked #{document_count} docs in #{duration_ms}ms" }
        callbacks.each { |cb| cb.call(event) }

        result
      end
    end
  end
end
