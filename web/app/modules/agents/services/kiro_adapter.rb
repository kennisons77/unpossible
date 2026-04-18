# frozen_string_literal: true

require "open3"
require "json"

module Agents
  class KiroAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 200_000

    def build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)
      system_content = assemble_system(node, context_chunks, principles)
      system_cost = estimate_tokens(system_content)
      remaining = token_budget - system_cost

      trimmed_turns = apply_turn_budget(turns, remaining)
      messages = trimmed_turns.map { |t| { role: turn_role(t[:kind]), content: t[:content] } }

      { model: "kiro", system: system_content, messages: messages }
    end

    # Kiro is a CLI tool — invoke kiro-cli as a subprocess.
    # The prompt is serialized to a single string: system + messages concatenated.
    def call_provider(prompt)
      text = build_cli_input(prompt)
      stdout, stderr, status = Open3.capture3("kiro-cli", "chat", "--no-interactive", "--trust-all-tools", "--", text)

      if status.success?
        { "content" => [{ "text" => stdout.strip }], "usage" => {}, "stop_reason" => "end_turn" }
      else
        Rails.logger.error("KiroAdapter: kiro-cli exited #{status.exitstatus}")
        { "error" => { "type" => "CliError", "message" => "Provider call failed" } }
      end
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

    def build_cli_input(prompt)
      parts = []
      parts << prompt[:system] if prompt[:system].present?
      Array(prompt[:messages]).each do |msg|
        parts << "#{msg[:role]}: #{msg[:content]}"
      end
      parts.join("\n\n")
    end
  end
end
