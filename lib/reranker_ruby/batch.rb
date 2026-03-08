# frozen_string_literal: true

module RerankerRuby
  # Batch reranking — run multiple queries against the same document set concurrently.
  #
  # Usage:
  #   results = RerankerRuby::Batch.rerank(reranker, queries, documents, top_k: 5, threads: 4)
  #   results[0]  # => results for queries[0]
  #   results[1]  # => results for queries[1]
  #
  class Batch
    # @param reranker [Base] any reranker instance
    # @param queries [Array<String>] list of queries
    # @param documents [Array] shared document set
    # @param top_k [Integer] number of results per query
    # @param threads [Integer] concurrency level
    # @return [Array<Array<Result>>] results per query
    def self.rerank(reranker, queries, documents, top_k: 10, threads: 4)
      if threads <= 1
        return queries.map { |q| reranker.rerank(q, documents, top_k: top_k) }
      end

      results = Array.new(queries.length)
      mutex = Mutex.new
      queue = Queue.new

      queries.each_with_index { |q, i| queue << [q, i] }
      threads.times { queue << nil } # sentinel values

      workers = threads.times.map do
        Thread.new do
          while (item = queue.pop)
            query, idx = item
            result = reranker.rerank(query, documents, top_k: top_k)
            mutex.synchronize { results[idx] = result }
          end
        end
      end

      workers.each(&:join)
      results
    end
  end
end
