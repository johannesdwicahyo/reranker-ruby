# frozen_string_literal: true

# Example: Using reranker-ruby with zvec-ruby for RAG pipeline
#
# Prerequisites:
#   gem install zvec-ruby reranker-ruby

require "reranker_ruby"
# require "zvec_ruby"  # uncomment when using with zvec-ruby

# 1. Vector search retrieves candidates (approximate)
# candidates = collection.search(query_embedding, top_k: 50)

# 2. Simulated vector search results
candidates = [
  { content: "Paris is the capital and largest city of France.", id: "doc1" },
  { content: "The Eiffel Tower is a wrought-iron lattice tower in Paris.", id: "doc2" },
  { content: "France is a country in Western Europe.", id: "doc3" },
  { content: "Berlin is the capital of Germany.", id: "doc4" },
  { content: "Lyon is the second-largest city in France.", id: "doc5" }
]

# 3. Rerank for precision
reranker = RerankerRuby::Cohere.new(api_key: ENV.fetch("COHERE_API_KEY"))

query = "What is the capital of France?"
documents = candidates.map do |c|
  { text: c[:content], id: c[:id] }
end

results = reranker.rerank(query, documents, top_k: 3)

puts "Query: #{query}"
puts "---"
results.each do |r|
  puts "#{r.score.round(4)} | [#{r.metadata[:id]}] #{r.text[0..60]}"
end
