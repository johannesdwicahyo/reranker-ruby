# frozen_string_literal: true

module RerankerRuby
  class Railtie < ::Rails::Railtie
    initializer "reranker_ruby.configure" do
      # Apply Rails logger if none configured
      config.after_initialize do
        if RerankerRuby.configuration.logger.nil?
          RerankerRuby::Logging.logger = Rails.logger
        else
          RerankerRuby::Logging.logger = RerankerRuby.configuration.logger
        end
      end
    end

    generators do
      require_relative "generators/install_generator"
    end
  end
end
