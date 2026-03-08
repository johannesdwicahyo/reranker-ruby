# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"

module RerankerRuby
  class ModelDownloader
    HF_BASE_URL = "https://huggingface.co"
    DEFAULT_CACHE_DIR = File.join(Dir.home, ".cache", "reranker-ruby", "models")

    # Known ONNX model paths for popular cross-encoder models
    ONNX_PATHS = {
      "cross-encoder/ms-marco-MiniLM-L-6-v2" => "onnx/model.onnx",
      "cross-encoder/ms-marco-MiniLM-L-12-v2" => "onnx/model.onnx",
      "BAAI/bge-reranker-base" => "onnx/model.onnx",
      "BAAI/bge-reranker-large" => "onnx/model.onnx",
      "BAAI/bge-reranker-v2-m3" => "onnx/model.onnx"
    }.freeze

    def initialize(cache_dir: DEFAULT_CACHE_DIR, token: nil)
      @cache_dir = cache_dir
      @token = token
    end

    # Downloads model and tokenizer files, returns paths
    # @return [Hash] { model_path:, tokenizer_path: }
    def download(repo_id)
      model_dir = File.join(@cache_dir, repo_id.gsub("/", "--"))
      FileUtils.mkdir_p(model_dir)

      onnx_path = ONNX_PATHS.fetch(repo_id, "onnx/model.onnx")

      model_path = File.join(model_dir, "model.onnx")
      tokenizer_path = File.join(model_dir, "tokenizer.json")

      download_file(repo_id, onnx_path, model_path) unless File.exist?(model_path)
      download_file(repo_id, "tokenizer.json", tokenizer_path) unless File.exist?(tokenizer_path)

      { model_path: model_path, tokenizer_path: tokenizer_path }
    end

    private

    def download_file(repo_id, remote_path, local_path)
      url = URI("#{HF_BASE_URL}/#{repo_id}/resolve/main/#{remote_path}")
      download_with_redirects(url, local_path)
    end

    def download_with_redirects(url, local_path, limit: 5)
      raise Error, "Too many redirects downloading #{url}" if limit == 0

      Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
        request = Net::HTTP::Get.new(url)
        request["Authorization"] = "Bearer #{@token}" if @token

        http.request(request) do |response|
          case response
          when Net::HTTPRedirection
            redirect_url = URI(response["location"])
            return download_with_redirects(redirect_url, local_path, limit: limit - 1)
          when Net::HTTPSuccess
            File.open(local_path, "wb") do |file|
              response.read_body { |chunk| file.write(chunk) }
            end
          else
            raise Error, "Failed to download #{url}: HTTP #{response.code}"
          end
        end
      end

      local_path
    end
  end
end
