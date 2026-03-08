# frozen_string_literal: true

require "reranker_ruby"

# Simulate results from two different retrieval strategies
vector_results = ["doc1", "doc3", "doc5", "doc7", "doc9"]
keyword_results = ["doc2", "doc1", "doc4", "doc3", "doc6"]

# Fuse with Reciprocal Rank Fusion
fused = RerankerRuby::RRF.fuse(vector_results, keyword_results, k: 60)

puts "Fused ranking:"
fused.each_with_index do |id, rank|
  puts "  #{rank + 1}. #{id}"
end

# Then rerank the top fused results with a cross-encoder
reranker = RerankerRuby::Cohere.new(api_key: ENV.fetch("COHERE_API_KEY"))

query = "What is the capital of France?"
# In a real app, you'd fetch document content by ID
documents = fused.first(5).map { |id| "Content of #{id}" }

results = reranker.rerank(query, documents, top_k: 3)

puts "\nReranked results:"
results.each do |r|
  puts "  #{r.score.round(4)} | #{r.text}"
end
