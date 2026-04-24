# frozen_string_literal: true

require "net/http"
require "json"

module Agents
  class ClaudeAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 150_000
    API_URL = URI("https://api.anthropic.com/v1/messages").freeze
    API_VERSION = "2023-06-01"

    def build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)
      system_blocks = assemble_system_blocks(node, context_chunks, principles)
      system_cost = estimate_tokens(system_blocks.sum { |b| b[:text].to_s.length })
      remaining = token_budget - system_cost

      trimmed_turns = apply_turn_budget(turns, remaining)
      messages = trimmed_turns.map { |t| { role: turn_role(t[:kind]), content: t[:content] } }

      { model: "claude-sonnet-4-20250514", system: system_blocks, messages: messages }
    end

    def call_provider(prompt)
      api_key = Secret.new(ENV.fetch("ANTHROPIC_API_KEY", ""))

      http = Net::HTTP.new(API_URL.host, API_URL.port)
      http.use_ssl = true
      http.read_timeout = 120

      request = Net::HTTP::Post.new(API_URL.path)
      request["Content-Type"] = "application/json"
      request["x-api-key"] = api_key.expose
      request["anthropic-version"] = API_VERSION
      request.body = prompt.to_json

      response = http.request(request)
      JSON.parse(response.body)
    rescue StandardError => e
      { "error" => { "type" => e.class.name, "message" => "Provider call failed" } }
    end

    def parse_response(raw_response)
      {
        text: raw_response.dig("content", 0, "text").to_s,
        input_tokens: raw_response.dig("usage", "input_tokens").to_i,
        output_tokens: raw_response.dig("usage", "output_tokens").to_i,
        stop_reason: raw_response["stop_reason"].to_s
      }
    end

    def max_context_tokens
      MAX_CONTEXT_TOKENS
    end

    private

    CACHE_CONTROL = { type: "ephemeral" }.freeze

    def assemble_system_blocks(node, context_chunks, principles)
      blocks = []
      # Volatile — node/task description changes per iteration, no caching
      blocks << { type: "text", text: node.to_s } if node.present?
      # Stable — principles and context are the same across iterations, cache them
      Array(principles).each { |p| blocks << { type: "text", text: p, cache_control: CACHE_CONTROL } }
      Array(context_chunks).each { |c| blocks << { type: "text", text: c, cache_control: CACHE_CONTROL } }
      blocks
    end

    def turn_role(kind)
      case kind
      when "human_input", "tool_result" then "user"
      else "assistant"
      end
    end
  end
end
