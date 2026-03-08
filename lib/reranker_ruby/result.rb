# frozen_string_literal: true

module RerankerRuby
  class Result
    attr_reader :text, :score, :index, :metadata

    def initialize(text:, score:, index:, metadata: {})
      @text = text
      @score = score.to_f
      @index = index
      @metadata = metadata
    end

    def to_h
      { text: @text, score: @score, index: @index, metadata: @metadata }
    end

    def <=>(other)
      other.score <=> @score
    end
  end
end
