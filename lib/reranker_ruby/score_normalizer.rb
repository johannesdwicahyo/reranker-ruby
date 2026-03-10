# frozen_string_literal: true

module RerankerRuby
  # Normalizes scores across different reranker models to a common [0, 1] scale.
  # Different models produce scores on different scales — this makes them comparable.
  module ScoreNormalizer
    # Min-max normalization to [0, 1]
    def self.min_max(results)
      return results if results.empty?

      scores = results.map(&:score)
      if scores.any? { |s| s.nan? || s.infinite? }
        return results.map { |r| with_score(r, 0.0) }
      end

      min = scores.min
      max = scores.max
      range = max - min

      return results.map { |r| with_score(r, 1.0) } if range.zero?

      results.map { |r| with_score(r, (r.score - min) / range) }
    end

    # Softmax normalization — scores sum to 1.0, preserves relative ordering
    def self.softmax(results)
      return results if results.empty?

      scores = results.map(&:score)
      if scores.any? { |s| s.nan? || s.infinite? }
        return results.map { |r| with_score(r, 0.0) }
      end

      max_score = scores.max
      exps = scores.map { |s| Math.exp(s - max_score) } # subtract max for numerical stability
      sum = exps.sum

      results.each_with_index.map do |r, i|
        with_score(r, exps[i] / sum)
      end
    end

    # Sigmoid normalization — each score independently mapped to [0, 1]
    def self.sigmoid(results)
      return results if results.empty?

      scores = results.map(&:score)
      if scores.any? { |s| s.nan? || s.infinite? }
        return results.map { |r| with_score(r, 0.0) }
      end

      results.map { |r| with_score(r, 1.0 / (1.0 + Math.exp(-r.score))) }
    end

    def self.with_score(result, new_score)
      Result.new(
        text: result.text,
        score: new_score,
        index: result.index,
        metadata: result.metadata
      )
    end
    private_class_method :with_score
  end
end
