# frozen_string_literal: true

require_relative "reranker_ruby/version"
require_relative "reranker_ruby/result"
require_relative "reranker_ruby/base"
require_relative "reranker_ruby/cohere"
require_relative "reranker_ruby/jina"
require_relative "reranker_ruby/rrf"
require_relative "reranker_ruby/model_downloader"
require_relative "reranker_ruby/score_normalizer"
require_relative "reranker_ruby/ensemble"
require_relative "reranker_ruby/batch"
require_relative "reranker_ruby/logging"
require_relative "reranker_ruby/cache/memory"
require_relative "reranker_ruby/configuration"
require_relative "reranker_ruby/middleware"

module RerankerRuby
  autoload :Onnx, "reranker_ruby/onnx"
  autoload :RerankJob, "reranker_ruby/rerank_job"
end

require_relative "reranker_ruby/railtie" if defined?(Rails::Railtie)
