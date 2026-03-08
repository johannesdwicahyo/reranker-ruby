# frozen_string_literal: true

module RerankerRuby
  # Pipeline middleware for integration with rag-ruby or any RAG pipeline.
  # Accepts candidates from a retrieval step and reranks them.
  #
  # Usage:
  #   middleware = RerankerRuby::Middleware.new(
  #     reranker: RerankerRuby::Cohere.new(api_key: "..."),
  #     top_k: 5,
  #     text_key: :content  # key to extract text from candidate hashes
  #   )
  #
  #   reranked = middleware.call(query: "test", candidates: candidates)
  #
  class Middleware
    def initialize(reranker: nil, top_k: nil, text_key: :text)
      @reranker = reranker
      @top_k = top_k
      @text_key = text_key
    end

    def call(query:, candidates:, top_k: nil)
      reranker = @reranker || RerankerRuby.reranker
      top_k ||= @top_k || RerankerRuby.configuration.default_top_k

      documents = candidates.map do |candidate|
        case candidate
        when Hash
          text = candidate[@text_key] || candidate[@text_key.to_s]
          metadata = candidate.reject { |k, _| k == @text_key || k == @text_key.to_s }
          { text: text }.merge(metadata)
        when String
          candidate
        else
          # Duck-type: try to call the text_key method
          if candidate.respond_to?(@text_key)
            { text: candidate.send(@text_key) }
          else
            candidate.to_s
          end
        end
      end

      reranker.rerank(query, documents, top_k: top_k)
    end
  end
end
