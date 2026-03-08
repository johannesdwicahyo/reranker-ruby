# frozen_string_literal: true

require "rails/generators"

module RerankerRuby
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Creates a RerankerRuby initializer file"

      def create_initializer_file
        create_file "config/initializers/reranker_ruby.rb", <<~RUBY
          # frozen_string_literal: true

          RerankerRuby.configure do |config|
            # Choose your reranking provider: :cohere, :jina, or :onnx
            config.default_provider = :cohere

            # API keys (use credentials or environment variables)
            config.cohere_api_key = ENV["COHERE_API_KEY"]
            # config.jina_api_key = ENV["JINA_API_KEY"]

            # Default number of top results to return
            config.default_top_k = 10

            # Optional: specify a model
            # config.default_model = "rerank-v3.5"

            # Optional: enable caching (:memory or :redis)
            # config.cache_store = :memory
            # config.cache_ttl = 3600

            # Optional: ONNX local model settings
            # config.default_provider = :onnx
            # config.onnx_model = "cross-encoder/ms-marco-MiniLM-L-6-v2"
          end
        RUBY
      end
    end
  end
end
