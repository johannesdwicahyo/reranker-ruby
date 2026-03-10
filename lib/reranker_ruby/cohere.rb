# frozen_string_literal: true

module RerankerRuby
  class Cohere < Base
    API_URL = "https://api.cohere.com/v2/rerank"
    DEFAULT_MODEL = "rerank-v3.5"

    def initialize(api_key:, model: DEFAULT_MODEL, **options)
      super(**options)
      @api_key = api_key
      @model = model
    end

    def rerank(query, documents, top_k: 10, model: nil)
      validate_inputs!(query, documents, top_k)
      instrument(query: query, document_count: documents.length, top_k: top_k) do
        with_cache(query, documents, top_k: top_k) do
          texts = extract_texts(documents)

          response = post(API_URL, {
            model: model || @model,
            query: query,
            documents: texts,
            top_n: top_k,
            return_documents: false
          }, headers: {
            "Authorization" => "Bearer #{@api_key}"
          })

          response["results"].map do |r|
            idx = r["index"]
            Result.new(
              text: texts[idx],
              score: r["relevance_score"],
              index: idx,
              metadata: extract_metadata(documents[idx])
            )
          end.sort
        end
      end
    end
  end
end
