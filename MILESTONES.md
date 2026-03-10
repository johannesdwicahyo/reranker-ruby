# Milestones

## v0.2.0 — Hardening & Reliability

Make the gem production-ready by fixing critical reliability and security issues.

### Security

- [ ] Replace `Marshal.load` in Redis cache with JSON serialization to prevent arbitrary code execution
- [ ] Add `User-Agent` header to all HTTP requests (`RerankerRuby/0.x.x`)

### HTTP Client

- [ ] Add configurable timeouts (`open_timeout`, `read_timeout`, `write_timeout`) with sensible defaults (30s)
- [ ] Add retry logic with exponential backoff for transient failures (429, 503, network errors)
- [ ] Add connection keep-alive for repeated requests to the same host
- [ ] Rescue `JSON::ParserError` on malformed API responses with clear error message
- [ ] Add request/response size limits to prevent OOM on pathological responses

### Input Validation

- [ ] Validate `top_k > 0` in all rerankers
- [ ] Validate query is not nil/empty
- [ ] Validate documents array is not empty
- [ ] Validate API keys are present at initialization (fail fast, not on first call)
- [ ] Validate `threads >= 1` in Batch

### Thread Safety

- [ ] Add mutex to `Cache::Memory` for concurrent read/write safety
- [ ] Make `Logging.callbacks` thread-safe (use mutex, iterate over frozen copy)
- [ ] Make `Configuration` singleton thread-safe with `Mutex`
- [ ] Propagate exceptions from Batch worker threads to the caller
- [ ] Collect and report per-query errors in Batch instead of silent failure

### Model Downloads

- [ ] Clean up partial files on failed/interrupted downloads
- [ ] Add SHA256 checksum verification for downloaded model files
- [ ] Add download progress logging
- [ ] Add file size validation (reject suspiciously small downloads)

---

## v0.3.0 — Performance & Efficiency

Reduce latency and resource usage for high-volume workloads.

### ONNX Inference

- [ ] Batch tokenization — encode multiple query-document pairs at once instead of one at a time
- [ ] Batch ONNX inference — run multiple pairs through the model in a single `session.run` call
- [ ] Add INT8 quantized model support for faster inference on CPU
- [ ] Cache tokenization results for repeated documents
- [ ] Log a warning when documents are truncated beyond `MAX_LENGTH`

### API Efficiency

- [ ] Connection pooling — reuse HTTP connections across multiple rerank calls
- [ ] Smarter Ensemble aggregation — request only `top_k * 2` from each reranker instead of all documents
- [ ] Support Cohere batch API (multiple queries in a single HTTP request)

### Memory

- [ ] Add max-size eviction policy to Memory cache (LRU)
- [ ] Background sweep for expired cache entries instead of lazy-only eviction
- [ ] Streaming document processing for very large document sets (>10k docs)

---

## v0.4.0 — Test Coverage & Robustness

Close all test coverage gaps and harden edge-case handling.

### Error Path Tests

- [ ] Test 400, 429, 503 API responses for Cohere and Jina
- [ ] Test malformed JSON response from API
- [ ] Test missing `results` key in API response
- [ ] Test network timeout and connection refused
- [ ] Test Redis connection failure in cache
- [ ] Test corrupted/poisoned cache data
- [ ] Test ONNX model file not found / invalid model
- [ ] Test HuggingFace download 404 (model doesn't exist)

### Edge Case Tests

- [ ] Test rerank with single document
- [ ] Test rerank with `top_k` larger than document count
- [ ] Test `top_k: 0`
- [ ] Test empty query string
- [ ] Test documents with special characters, unicode, very long text
- [ ] Test NaN / Infinity scores in normalizer
- [ ] Test Ensemble when one reranker returns fewer results than another
- [ ] Test Batch with exception in one worker thread
- [ ] Test cache with same query+docs but different `top_k`
- [ ] Test RRF with duplicate IDs in the same ranked list

### Integration Tests

- [ ] Add optional live API integration tests (skipped in CI, run manually)
- [ ] Add real ONNX model inference test with ms-marco-MiniLM
- [ ] Benchmark: measure latency for 10/100/1000 documents per provider

---

## v0.5.0 — Developer Experience

Improve API consistency, error messages, and documentation.

### API Consistency

- [ ] Unify cache interface — add `size` method to Redis cache
- [ ] Standardize constructor signatures across Cohere, Jina, Onnx
- [ ] Consistent symbol/string key handling in metadata (always symbolize)
- [ ] Add `#inspect` to Result for better REPL/debugging output

### Error Messages

- [ ] Include request details (URL, query length, doc count) in APIError
- [ ] Better error message when ONNX model expects different input shape
- [ ] Better error message when `Object.const_get(callback)` fails in RerankJob
- [ ] Add error classes: `TimeoutError`, `RateLimitError`, `ValidationError`

### Logging

- [ ] Log HTTP request/response details at DEBUG level
- [ ] Log cache hits/misses
- [ ] Log model download progress
- [ ] Log ONNX inference time per document
- [ ] Add structured logging option (JSON format for log aggregators)

### Documentation

- [ ] Add YARD documentation to all public methods
- [ ] Add `examples/ensemble.rb`
- [ ] Add `examples/rails_pipeline.rb`
- [ ] Add `examples/batch_rerank.rb`
- [ ] Add benchmarking script (`bin/benchmark`)

---

## v0.6.0 — Advanced Features

Add capabilities that differentiate from basic reranking wrappers.

### Fallback Chains

- [ ] `RerankerRuby::Fallback` — try provider A, fall back to B on failure
- [ ] Configurable fallback triggers (timeout, error, low confidence)
- [ ] Circuit breaker pattern — stop calling failed provider for cooldown period

### Async API

- [ ] Fiber-based async reranking for concurrent I/O without threads
- [ ] `rerank_async` returning a Future/Promise object
- [ ] Support for `async` gem integration

### Score Calibration

- [ ] Cross-model score mapping (calibrate Cohere scores to match Jina scale)
- [ ] Confidence thresholding — filter results below a score threshold
- [ ] Score distribution analysis — detect when model returns uniform/degenerate scores

### Advanced RRF

- [ ] Weighted RRF — assign different weights to different ranked lists
- [ ] Condorcet fusion as alternative to RRF
- [ ] Borda count fusion

### Observability

- [ ] ActiveSupport::Notifications integration for Rails apps
- [ ] Prometheus/StatsD metrics export
- [ ] OpenTelemetry tracing spans for rerank calls

---

## v1.0.0 — Stable Release

Production-stable API with backwards compatibility guarantees.

### Stability

- [ ] Freeze public API — no breaking changes without major version bump
- [ ] Semantic versioning enforcement
- [ ] Deprecation warnings for any API changes (minimum 1 minor version notice)
- [ ] Full YARD documentation coverage
- [ ] 100% test coverage on public API surface

### Ecosystem

- [ ] Rails generator for ActiveRecord model with reranking concern
- [ ] `acts_as_reranked` mixin for ActiveRecord models
- [ ] Integration guide for `zvec-ruby` (vector search → rerank pipeline)
- [ ] Integration guide for `rag-ruby`
- [ ] Heroku/Docker deployment guide

### Performance Baseline

- [ ] Published benchmarks: latency per provider, throughput at concurrency levels
- [ ] Memory profiling results for large document sets
- [ ] CI performance regression tests

---

## Future Ideas (Unscheduled)

These are ideas worth exploring but not yet committed to a milestone.

- **Hybrid ONNX + API** — use local model for pre-filtering, API for final ranking
- **Fine-tuning support** — export training data from rerank results for model improvement
- **Attention visualization** — extract and display cross-encoder attention weights
- **Streaming rerank** — yield results as they're scored instead of waiting for all
- **Model auto-selection** — pick the best model based on query language/domain
- **A/B testing** — compare rerankers side-by-side with statistical significance
- **Custom ONNX model export** — helper to convert HuggingFace PyTorch models to ONNX
- **WebAssembly inference** — run models in browser via wasm for edge deployments
- **gRPC provider** — support gRPC-based reranking services
- **LLM-as-reranker** — use Claude/GPT to rerank via prompting (expensive but flexible)
