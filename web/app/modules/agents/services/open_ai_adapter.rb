# frozen_string_literal: true

require "net/http"
require "json"

module Agents
  class OpenAiAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 128_000
    API_URL = URI("https://api.openai.com/v1/chat/completions").freeze

    def build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)
      system_content = assemble_system(node, context_chunks, principles)
      system_cost = estimate_tokens(system_content)
      remaining = token_budget - system_cost

      trimmed_turns = apply_turn_budget(turns, remaining)

      # OpenAI uses a flat messages array with an optional system message prepended
      messages = []
      messages << { role: "system", content: system_content } if system_content.present?
      messages.concat(trimmed_turns.map { |t| { role: turn_role(t[:kind]), content: t[:content] } })

      { model: "gpt-4o", messages: messages }
    end

    def call_provider(prompt)
      api_key = Secret.new(ENV.fetch("OPENAI_API_KEY", ""))

      http = Net::HTTP.new(API_URL.host, API_URL.port)
      http.use_ssl = true
      http.read_timeout = 120

      request = Net::HTTP::Post.new(API_URL.path)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{api_key.expose}"
      request.body = prompt.to_json

      response = http.request(request)
      JSON.parse(response.body)
    rescue StandardError => e
      { "error" => { "type" => e.class.name, "message" => "Provider call failed" } }
    end

    def parse_response(raw_response)
      {
        text: raw_response.dig("choices", 0, "message", "content").to_s,
        input_tokens: raw_response.dig("usage", "prompt_tokens").to_i,
        output_tokens: raw_response.dig("usage", "completion_tokens").to_i,
        stop_reason: raw_response.dig("choices", 0, "finish_reason").to_s
      }
    end

    def max_context_tokens
      MAX_CONTEXT_TOKENS
    end

    private

    def assemble_system(node, context_chunks, principles)
      parts = []
      parts << node.to_s if node.present?
      parts.concat(Array(principles))
      parts.concat(Array(context_chunks))
      parts.join("\n\n")
    end

    def turn_role(kind)
      case kind
      when "human_input", "tool_result" then "user"
      else "assistant"
      end
    end
  end
end
