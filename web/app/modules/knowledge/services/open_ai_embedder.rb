# frozen_string_literal: true

require "net/http"
require "json"

module Knowledge
  class OpenAiEmbedder < EmbedderService
    MODEL = "text-embedding-3-small"
    URL = URI("https://api.openai.com/v1/embeddings")

    def initialize
      @api_key = Secret.new(ENV.fetch("OPENAI_API_KEY"))
    end

    def embed(text)
      response = request(text)
      body = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        raise "OpenAI embedding request failed: #{body.dig('error', 'message') || response.code}"
      end

      body.dig("data", 0, "embedding")
    end

    private

    def request(text)
      req = Net::HTTP::Post.new(URL)
      req["Authorization"] = "Bearer #{@api_key.expose}"
      req["Content-Type"] = "application/json"
      req.body = { model: MODEL, input: text }.to_json

      Net::HTTP.start(URL.host, URL.port, use_ssl: true) { |http| http.request(req) }
    end
  end
end
