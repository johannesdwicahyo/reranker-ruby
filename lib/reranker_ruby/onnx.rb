# frozen_string_literal: true

module RerankerRuby
  class Onnx < Base
    DEFAULT_MODEL = "cross-encoder/ms-marco-MiniLM-L-6-v2"
    MAX_LENGTH = 512

    def initialize(model: nil, model_path: nil, tokenizer: nil, cache_dir: nil, **options)
      super(**options)
      require_dependencies!

      if model_path
        @model_path = model_path
        tokenizer_id = tokenizer || DEFAULT_MODEL
        @tokenizer = Tokenizers.from_pretrained(tokenizer_id)
      else
        repo_id = model || DEFAULT_MODEL
        downloader = ModelDownloader.new(cache_dir: cache_dir || ModelDownloader::DEFAULT_CACHE_DIR)
        paths = downloader.download(repo_id)
        @model_path = paths[:model_path]
        @tokenizer = Tokenizers.from_file(paths[:tokenizer_path])
      end

      @session = OnnxRuntime::InferenceSession.new(@model_path)
      @tokenizer.enable_truncation(MAX_LENGTH)
    end

    def rerank(query, documents, top_k: 10)
      with_cache(query, documents) do
        texts = extract_texts(documents)

        scores = texts.map { |text| score_pair(query, text) }

        results = texts.each_with_index.map do |text, idx|
          Result.new(
            text: text,
            score: scores[idx],
            index: idx,
            metadata: extract_metadata(documents[idx])
          )
        end

        results.sort.first(top_k)
      end
    end

    private

    def require_dependencies!
      require "onnxruntime" unless defined?(OnnxRuntime)
      require "tokenizers" unless defined?(Tokenizers)
    rescue LoadError => e
      raise Error, "Missing dependency for local inference: #{e.message}. " \
                   "Install with: gem install onnxruntime tokenizers"
    end

    def score_pair(query, document)
      encoding = @tokenizer.encode(query, document, add_special_tokens: true)

      inputs = {
        "input_ids" => [encoding.ids],
        "attention_mask" => [encoding.attention_mask]
      }

      # Some models also need token_type_ids
      if @session.inputs.any? { |i| i[:name] == "token_type_ids" }
        inputs["token_type_ids"] = [encoding.type_ids]
      end

      output = @session.run(nil, inputs)
      logit = output[0][0][0]

      sigmoid(logit)
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end
  end
end
