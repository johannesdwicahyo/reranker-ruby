# frozen_string_literal: true

require_relative "lib/reranker_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "reranker-ruby"
  spec.version = RerankerRuby::VERSION
  spec.authors = ["Johannes Dwi Cahyo"]
  spec.homepage = "https://github.com/johannesdwicahyo/reranker-ruby"
  spec.summary = "Cross-encoder reranking for Ruby RAG pipelines"
  spec.description = "A cross-encoder reranking library for Ruby. Supports Cohere, Jina, and local ONNX models. The single biggest quality improvement you can add to a RAG pipeline."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + %w[LICENSE README.md CHANGELOG.md]
  spec.require_paths = ["lib"]

  spec.add_dependency "logger"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
