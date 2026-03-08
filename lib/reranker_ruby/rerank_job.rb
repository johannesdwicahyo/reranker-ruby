# frozen_string_literal: true

module RerankerRuby
  # ActiveJob for async reranking of large result sets.
  #
  # Usage:
  #   RerankerRuby::RerankJob.perform_later(
  #     query: "What is Ruby?",
  #     documents: ["doc1", "doc2", ...],
  #     top_k: 5,
  #     callback: "MyCallback"
  #   )
  #
  # The callback class must implement .on_rerank_complete(query, results):
  #
  #   class MyCallback
  #     def self.on_rerank_complete(query, results)
  #       # results is an array of hashes: [{ text:, score:, index:, metadata: }, ...]
  #     end
  #   end
  #
  class RerankJob < ActiveJob::Base
    queue_as :default

    def perform(query:, documents:, top_k: nil, callback: nil)
      top_k ||= RerankerRuby.configuration.default_top_k
      results = RerankerRuby.rerank(query, documents, top_k: top_k)

      if callback
        callback_class = Object.const_get(callback)
        callback_class.on_rerank_complete(query, results.map(&:to_h))
      end

      results
    end
  end
end
