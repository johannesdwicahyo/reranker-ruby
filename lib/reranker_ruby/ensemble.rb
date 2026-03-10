# frozen_string_literal: true

module RerankerRuby
  # Combines results from multiple rerankers using weighted score aggregation.
  #
  # Usage:
  #   ensemble = RerankerRuby::Ensemble.new(
  #     rerankers: [cohere_reranker, jina_reranker],
  #     weights: [0.6, 0.4],
  #     normalize: :min_max
  #   )
  #   results = ensemble.rerank(query, documents, top_k: 5)
  #
  class Ensemble < Base
    # @param rerankers [Array<Base>] list of reranker instances
    # @param weights [Array<Float>, nil] weights for each reranker (default: equal)
    # @param normalize [Symbol] normalization strategy (:min_max, :softmax, :sigmoid, or :none)
    def initialize(rerankers:, weights: nil, normalize: :min_max, **options)
      super(**options)
      @rerankers = rerankers
      @weights = weights || Array.new(rerankers.length, 1.0 / rerankers.length)
      @normalize = normalize

      if @weights.length != @rerankers.length
        raise ArgumentError, "weights length (#{@weights.length}) must match rerankers length (#{@rerankers.length})"
      end
    end

    def rerank(query, documents, top_k: 10)
      validate_inputs!(query, documents, top_k)
      with_cache(query, documents, top_k: top_k) do
        texts = extract_texts(documents)

        # Collect and normalize results from each reranker
        all_results = @rerankers.map do |reranker|
          raw = reranker.rerank(query, documents, top_k: texts.length)
          normalize_results(raw)
        end

        # Aggregate scores by original document index
        aggregated = Hash.new(0.0)
        all_results.each_with_index do |results, reranker_idx|
          weight = @weights[reranker_idx]
          results.each do |result|
            aggregated[result.index] += result.score * weight
          end
        end

        # Build final results sorted by aggregated score
        aggregated.map do |idx, score|
          Result.new(
            text: texts[idx],
            score: score,
            index: idx,
            metadata: extract_metadata(documents[idx])
          )
        end.sort.first(top_k)
      end
    end

    private

    def normalize_results(results)
      case @normalize
      when :min_max  then ScoreNormalizer.min_max(results)
      when :softmax  then ScoreNormalizer.softmax(results)
      when :sigmoid  then ScoreNormalizer.sigmoid(results)
      when :none     then results
      else raise ArgumentError, "Unknown normalization: #{@normalize}"
      end
    end
  end
end
