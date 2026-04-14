# reranker-ruby — Milestones

> **Source of truth:** https://github.com/johannesdwicahyo/reranker-ruby/milestones
> **Last synced:** 2026-04-14

This file mirrors the GitHub milestones for this repo. Edit the milestone or issues on GitHub and re-sync, do not hand-edit.

## v1.0.0 — Stable Release (**open**)

_Frozen public API, full docs, ecosystem integrations, performance baselines_

_No issues._ (0 open, 0 closed reported)

## v0.6.0 — Advanced Features (**open**)

_Fallback chains, async API, score calibration, advanced fusion, observability_

_No issues._ (0 open, 0 closed reported)

## v0.5.0 — Developer Experience (**open**)

_API consistency, better error messages, structured logging, YARD docs, examples_

_No issues._ (0 open, 0 closed reported)

## v0.4.0 — Test Coverage & Robustness (**open**)

_Close all test coverage gaps: error paths, edge cases, integration tests, benchmarks_

_No issues._ (0 open, 0 closed reported)

## v0.3.0 — Performance & Efficiency (**open**)

_Reduce latency and resource usage: batch ONNX inference, connection pooling, LRU cache eviction, smarter ensemble aggregation_

_No issues._ (0 open, 0 closed reported)

## v0.2.0 — Hardening & Reliability (**closed**)

_Make the gem production-ready: security fixes, HTTP timeouts/retries, input validation, thread safety, download integrity_

- [x] #1 Connection pooling for HTTP clients
- [x] #2 Request timeout configuration
- [x] #3 Rate limit handling with Retry-After header
- [x] #4 Batch reranking with configurable concurrency
- [x] #5 Add Voyage AI reranker backend
- [x] #6 Add cross-encoder local reranker via onnx-ruby
- [x] #7 Cache TTL configuration and cache invalidation
- [x] #8 Comprehensive test coverage for all backends
- [x] #9 Error handling improvements with typed exceptions
- [x] #10 Thread safety audit
