# reranker-ruby

Cross-encoder reranking for Ruby RAG pipelines.

After vector search retrieves candidate documents, a reranker scores each candidate against the query using a cross-encoder model, producing far more accurate relevance rankings than embedding similarity alone. This is the single biggest quality improvement you can add to a RAG pipeline.

```
Bi-encoder (embedding search):   score = cosine(embed(query), embed(doc))  — fast, approximate
Cross-encoder (reranking):       score = model(query + doc)                 — slow, precise
```

The pattern: use bi-encoder for top-100 retrieval, then cross-encoder to rerank to top-10.

## Installation

Add to your Gemfile:

```ruby
gem "reranker-ruby"
```

For local ONNX inference, also install:

```ruby
gem "onnxruntime"
gem "tokenizers"
```

## Quick Start

```ruby
require "reranker_ruby"

reranker = RerankerRuby::Cohere.new(api_key: ENV["COHERE_API_KEY"])

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
# 0.9987 | Paris is the capital and largest city of France.
# 0.8234 | The Eiffel Tower is located in Paris.
# 0.6123 | Lyon is the second-largest city in France.
```

## Providers

### Cohere Rerank

```ruby
reranker = RerankerRuby::Cohere.new(api_key: ENV["COHERE_API_KEY"])
results = reranker.rerank(query, documents, top_k: 3)
```

Uses [Cohere Rerank API v2](https://docs.cohere.com/reference/rerank) with the `rerank-v3.5` model by default.

### Jina Rerank

```ruby
reranker = RerankerRuby::Jina.new(api_key: ENV["JINA_API_KEY"])
results = reranker.rerank(query, documents, top_k: 3)
```

Uses `jina-reranker-v2-base-multilingual` by default.

### Local ONNX Inference

Run cross-encoder models locally without API calls. Models are auto-downloaded from HuggingFace Hub.

```ruby
reranker = RerankerRuby::Onnx.new(
  model: "cross-encoder/ms-marco-MiniLM-L-6-v2"
)
results = reranker.rerank(query, documents, top_k: 3)
```

Or use a local model file:

```ruby
reranker = RerankerRuby::Onnx.new(
  model_path: "/path/to/reranker.onnx",
  tokenizer: "cross-encoder/ms-marco-MiniLM-L-6-v2"
)
```

Supported models:
- `cross-encoder/ms-marco-MiniLM-L-6-v2`
- `cross-encoder/ms-marco-MiniLM-L-12-v2`
- `BAAI/bge-reranker-base`
- `BAAI/bge-reranker-large`
- `BAAI/bge-reranker-v2-m3`

Requires the `onnxruntime` and `tokenizers` gems.

## Result Object

Every reranker returns an array of `Result` objects, sorted by relevance (highest first):

```ruby
result.text      # => "Paris is the capital..."
result.score     # => 0.9987
result.index     # => 0 (position in the original document array)
result.metadata  # => {} (preserved from input)
result.to_h      # => { text: "...", score: 0.9987, index: 0, metadata: {} }
```

## Structured Documents with Metadata

Pass hashes instead of strings. Metadata is preserved through reranking:

```ruby
documents = [
  { text: "Paris is the capital...", source: "wiki", id: "doc1" },
  { text: "France is a country...", source: "wiki", id: "doc2" },
]

results = reranker.rerank(query, documents, top_k: 3)
results.first.metadata  # => { source: "wiki", id: "doc1" }
```

## Reciprocal Rank Fusion

Combine results from multiple retrieval strategies before reranking:

```ruby
vector_results = collection.search(embedding, top_k: 50)
keyword_results = Article.where("content LIKE ?", "%#{query}%").limit(50)

fused = RerankerRuby::RRF.fuse(
  vector_results.map(&:id),
  keyword_results.map(&:id),
  k: 60
)
# => ranked array of IDs by combined relevance

# Then rerank the fused results for final precision
top_docs = fused.first(20).map { |id| Document.find(id) }
final = reranker.rerank(query, top_docs.map(&:content), top_k: 5)
```

## Ensemble Reranking

Combine multiple rerankers with weighted score aggregation:

```ruby
cohere = RerankerRuby::Cohere.new(api_key: ENV["COHERE_API_KEY"])
jina = RerankerRuby::Jina.new(api_key: ENV["JINA_API_KEY"])

ensemble = RerankerRuby::Ensemble.new(
  rerankers: [cohere, jina],
  weights: [0.6, 0.4],
  normalize: :min_max  # :min_max, :softmax, :sigmoid, or :none
)

results = ensemble.rerank(query, documents, top_k: 5)
```

## Score Normalization

Different models produce scores on different scales. Normalize them for comparison:

```ruby
results = reranker.rerank(query, documents)

# Min-max to [0, 1]
normalized = RerankerRuby::ScoreNormalizer.min_max(results)

# Softmax (scores sum to 1.0)
normalized = RerankerRuby::ScoreNormalizer.softmax(results)

# Sigmoid (each score independently mapped to [0, 1])
normalized = RerankerRuby::ScoreNormalizer.sigmoid(results)
```

## Batch Reranking

Rerank multiple queries concurrently:

```ruby
queries = ["capital of France?", "tallest building?", "largest ocean?"]

results = RerankerRuby::Batch.rerank(
  reranker, queries, documents,
  top_k: 5,
  threads: 4
)

results[0]  # => results for queries[0]
results[1]  # => results for queries[1]
```

## Caching

Avoid duplicate API calls for the same query+documents:

```ruby
# In-memory cache
reranker = RerankerRuby::Cohere.new(
  api_key: ENV["COHERE_API_KEY"],
  cache: RerankerRuby::Cache::Memory.new(ttl: 3600)
)

# Redis cache
require "redis"
reranker = RerankerRuby::Cohere.new(
  api_key: ENV["COHERE_API_KEY"],
  cache: RerankerRuby::Cache::Redis.new(redis: Redis.new, ttl: 3600)
)

reranker.rerank(query, docs, top_k: 5)  # API call
reranker.rerank(query, docs, top_k: 5)  # cache hit
```

## Logging & Metrics

Every rerank call is automatically instrumented:

```ruby
# Set log level
RerankerRuby::Logging.logger = Logger.new($stdout)
RerankerRuby::Logging.logger.level = Logger::INFO

# Subscribe to rerank events
RerankerRuby::Logging.on_rerank do |event|
  puts "#{event[:reranker]} reranked #{event[:document_count]} docs in #{event[:duration_ms]}ms"
  # event keys: :reranker, :query, :document_count, :top_k,
  #             :result_count, :duration_ms, :top_score
end
```

## Rails Integration

### Configuration

Run the install generator:

```bash
rails generate reranker_ruby:install
```

This creates `config/initializers/reranker_ruby.rb`:

```ruby
RerankerRuby.configure do |config|
  config.default_provider = :cohere         # :cohere, :jina, or :onnx
  config.cohere_api_key = ENV["COHERE_API_KEY"]
  config.default_top_k = 10
  config.cache_store = :memory              # :memory, :redis, or nil
  config.cache_ttl = 3600
end
```

Then use the global convenience method anywhere:

```ruby
results = RerankerRuby.rerank("What is Ruby?", documents, top_k: 5)
```

### ActiveJob for Async Reranking

For large result sets, run reranking in the background:

```ruby
RerankerRuby::RerankJob.perform_later(
  query: "What is Ruby?",
  documents: ["doc1", "doc2", ...],
  top_k: 5,
  callback: "MyRerankCallback"
)

# Callback class
class MyRerankCallback
  def self.on_rerank_complete(query, results)
    # results is an array of hashes: [{ text:, score:, index:, metadata: }, ...]
  end
end
```

### Pipeline Middleware

Plug into any RAG pipeline as a reranking step:

```ruby
middleware = RerankerRuby::Middleware.new(
  reranker: RerankerRuby::Cohere.new(api_key: "..."),
  top_k: 5,
  text_key: :content
)

# Works with hashes, strings, or objects
candidates = [
  { content: "Paris is the capital...", source: "wiki" },
  { content: "Berlin is the capital...", source: "wiki" },
]

results = middleware.call(query: "capital of France?", candidates: candidates)
```

## Dependencies

**Runtime:** `net/http` (stdlib), `json` (stdlib), `logger`

**Optional:** `onnxruntime` and `tokenizers` (for local ONNX inference), `redis` (for Redis caching)

**Development:** `minitest`, `rake`, `webmock`

## License

MIT
