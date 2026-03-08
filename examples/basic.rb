# frozen_string_literal: true

require "reranker_ruby"

# Cohere Rerank
reranker = RerankerRuby::Cohere.new(api_key: ENV.fetch("COHERE_API_KEY"))

query = "What is the capital of France?"
documents = [
  "Paris is the capital and largest city of France.",
  "France is a country in Western Europe.",
  "The Eiffel Tower is located in Paris.",
  "Berlin is the capital of Germany.",
  "Lyon is the second-largest city in France."
]

results = reranker.rerank(query, documents, top_k: 3)

results.each do |r|
  puts "#{r.score.round(4)} | #{r.text[0..60]}"
end
