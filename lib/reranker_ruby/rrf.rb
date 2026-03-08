# frozen_string_literal: true

module RerankerRuby
  class RRF
    def self.fuse(*ranked_lists, k: 60)
      scores = Hash.new(0.0)
      ranked_lists.each do |list|
        list.each_with_index do |id, rank|
          scores[id] += 1.0 / (k + rank + 1)
        end
      end
      scores.sort_by { |_, score| -score }.map(&:first)
    end
  end
end
