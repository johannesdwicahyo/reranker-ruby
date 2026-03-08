# Changelog

## 0.1.0 (2026-03-08)

- Initial release with all four phases
- Cohere Rerank API v2 support
- Jina Reranker API support
- Local ONNX cross-encoder inference with auto-download from HuggingFace
- Tokenization via tokenizers gem
- Sigmoid score normalization for local models
- Support for ms-marco-MiniLM and BGE reranker models
- Ensemble reranker with weighted score aggregation
- Score calibration (min-max, softmax, sigmoid normalization)
- Concurrent batch reranking with configurable thread pool
- Logging and metrics with event callbacks
- Pipeline middleware for RAG integration
- Rails configuration via initializer (rails generate reranker_ruby:install)
- ActiveJob for async reranking (RerankerRuby::RerankJob)
- Global configuration and convenience API (RerankerRuby.rerank)
- Reciprocal Rank Fusion (RRF)
- In-memory and Redis caching with TTL
- String and hash document support with metadata preservation
