# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agents::ProviderAdapter do
  describe ".for" do
    it "returns ClaudeAdapter for 'claude'" do
      adapter = described_class.for("claude")
      expect(adapter).to be_a(Agents::ClaudeAdapter)
    end

    it "returns KiroAdapter for 'kiro'" do
      adapter = described_class.for("kiro")
      expect(adapter).to be_a(Agents::KiroAdapter)
    end

    it "returns OpenAiAdapter for 'openai'" do
      adapter = described_class.for("openai")
      expect(adapter).to be_a(Agents::OpenAiAdapter)
    end

    it "raises ArgumentError for unknown provider" do
      expect { described_class.for("unknown") }.to raise_error(ArgumentError, /Unknown provider/)
    end
  end

  describe "interface enforcement" do
    subject(:adapter) { described_class.new }

    it "raises NotImplementedError for build_prompt" do
      expect { adapter.build_prompt(node: nil, context_chunks: [], principles: [], turns: [], token_budget: 1000) }
        .to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for call_provider" do
      expect { adapter.call_provider({}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for parse_response" do
      expect { adapter.parse_response({}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for max_context_tokens" do
      expect { adapter.max_context_tokens }.to raise_error(NotImplementedError)
    end
  end

  # Shared examples for pinned+sliding token budget behaviour
  shared_examples "pinned+sliding token budget" do |adapter_class|
    subject(:adapter) { adapter_class.new }

    let(:base_args) { { node: "spec/foo.md", context_chunks: [], principles: [], token_budget: 200_000 } }

    def turn(kind, content, position)
      { kind: kind, content: content, position: position }
    end

    it "always includes agent_question turns" do
      turns = [turn("agent_question", "What env?", 1), turn("human_input", "staging", 2)]
      result = adapter.build_prompt(**base_args, turns: turns)
      contents = result[:messages].map { |m| m[:content] }
      expect(contents).to include("What env?", "staging")
    end

    it "always includes human_input turns" do
      turns = [turn("human_input", "my answer", 1)]
      result = adapter.build_prompt(**base_args, turns: turns)
      contents = result[:messages].map { |m| m[:content] }
      expect(contents).to include("my answer")
    end

    it "trims oldest llm_response turns when over budget" do
      # Budget tight enough to force trimming: system is empty, each turn ~1 token
      # Make old llm_response very large so it gets dropped
      old_response = "x" * 4000  # ~1000 tokens
      new_response = "y" * 4     # ~1 token
      turns = [
        turn("llm_response", old_response, 1),
        turn("llm_response", new_response, 2)
      ]
      # Budget: 1100 tokens — old response alone is ~1000, new is ~1, pinned is 0
      # With budget 1100, both fit. Use 50 to force dropping old.
      result = adapter.build_prompt(**base_args, turns: turns, token_budget: 50)
      contents = result[:messages].map { |m| m[:content] }
      expect(contents).not_to include(old_response)
      expect(contents).to include(new_response)
    end

    it "trims oldest tool_result turns when over budget" do
      old_tool = "a" * 4000
      new_tool = "b" * 4
      turns = [
        turn("tool_result", old_tool, 1),
        turn("tool_result", new_tool, 2)
      ]
      result = adapter.build_prompt(**base_args, turns: turns, token_budget: 50)
      contents = result[:messages].map { |m| m[:content] }
      expect(contents).not_to include(old_tool)
      expect(contents).to include(new_tool)
    end

    it "raises TokenBudgetExceeded when pinned turns alone exceed budget" do
      # agent_question + human_input together exceed tiny budget
      turns = [
        turn("agent_question", "x" * 400, 1),  # ~100 tokens
        turn("human_input", "y" * 400, 2)       # ~100 tokens
      ]
      expect {
        adapter.build_prompt(**base_args, turns: turns, token_budget: 10)
      }.to raise_error(Agents::ProviderAdapter::TokenBudgetExceeded)
    end
  end

  describe Agents::ClaudeAdapter do
    subject(:adapter) { described_class.new }

    include_examples "pinned+sliding token budget", Agents::ClaudeAdapter

    it "builds a prompt with claude model" do
      result = adapter.build_prompt(
        node: "spec/foo.md", context_chunks: ["ctx"], principles: ["be concise"],
        turns: [{ kind: "human_input", content: "hello", position: 1 }],
        token_budget: 200_000
      )
      expect(result[:model]).to eq("claude-sonnet-4-20250514")
      expect(result[:messages]).to eq([{ role: "user", content: "hello" }])
    end

    it "returns system as an array of content blocks" do
      result = adapter.build_prompt(
        node: "node-ref", context_chunks: ["chunk1"], principles: ["principle1"],
        turns: [], token_budget: 200_000
      )
      texts = result[:system].map { |b| b[:text] }
      expect(texts).to include("node-ref", "principle1", "chunk1")
    end

    it "applies cache_control to principles and context_chunks but not node" do
      result = adapter.build_prompt(
        node: "node-ref", context_chunks: ["chunk1"], principles: ["principle1"],
        turns: [], token_budget: 200_000
      )
      node_block = result[:system].find { |b| b[:text] == "node-ref" }
      principle_block = result[:system].find { |b| b[:text] == "principle1" }
      chunk_block = result[:system].find { |b| b[:text] == "chunk1" }

      expect(node_block).not_to have_key(:cache_control)
      expect(principle_block[:cache_control]).to eq({ type: "ephemeral" })
      expect(chunk_block[:cache_control]).to eq({ type: "ephemeral" })
    end

    it "parses response returning normalised hash" do
      raw = { "content" => [{ "text" => "response text" }], "usage" => { "input_tokens" => 10, "output_tokens" => 5 }, "stop_reason" => "end_turn" }
      result = adapter.parse_response(raw)
      expect(result).to eq(text: "response text", input_tokens: 10, output_tokens: 5, stop_reason: "end_turn")
    end

    it "handles missing fields gracefully" do
      result = adapter.parse_response({})
      expect(result).to eq(text: "", input_tokens: 0, output_tokens: 0, stop_reason: "")
    end

    it "returns max context tokens" do
      expect(adapter.max_context_tokens).to eq(150_000)
    end
  end

  describe Agents::KiroAdapter do
    subject(:adapter) { described_class.new }

    include_examples "pinned+sliding token budget", Agents::KiroAdapter

    it "builds a prompt with kiro model" do
      result = adapter.build_prompt(
        node: nil, context_chunks: [], principles: [],
        turns: [{ kind: "human_input", content: "hello", position: 1 }],
        token_budget: 200_000
      )
      expect(result[:model]).to eq("kiro")
    end

    it "parses response returning normalised hash" do
      raw = { "content" => [{ "text" => "response text" }], "usage" => { "input_tokens" => 10, "output_tokens" => 5 }, "stop_reason" => "end_turn" }
      result = adapter.parse_response(raw)
      expect(result).to eq(text: "response text", input_tokens: 10, output_tokens: 5, stop_reason: "end_turn")
    end

    it "handles missing fields gracefully" do
      result = adapter.parse_response({})
      expect(result).to eq(text: "", input_tokens: 0, output_tokens: 0, stop_reason: "")
    end

    it "returns max context tokens" do
      expect(adapter.max_context_tokens).to eq(200_000)
    end
  end

  describe Agents::OpenAiAdapter do
    subject(:adapter) { described_class.new }

    include_examples "pinned+sliding token budget", Agents::OpenAiAdapter

    it "builds a prompt with gpt-4o model and system message" do
      result = adapter.build_prompt(
        node: "node-ref", context_chunks: [], principles: [],
        turns: [{ kind: "human_input", content: "hello", position: 1 }],
        token_budget: 200_000
      )
      expect(result[:model]).to eq("gpt-4o")
      system_msg = result[:messages].find { |m| m[:role] == "system" }
      expect(system_msg[:content]).to include("node-ref")
      user_msg = result[:messages].find { |m| m[:role] == "user" }
      expect(user_msg[:content]).to eq("hello")
    end

    it "parses response returning normalised hash" do
      raw = { "choices" => [{ "message" => { "content" => "response text" }, "finish_reason" => "stop" }], "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 } }
      result = adapter.parse_response(raw)
      expect(result).to eq(text: "response text", input_tokens: 10, output_tokens: 5, stop_reason: "stop")
    end

    it "handles missing fields gracefully" do
      result = adapter.parse_response({})
      expect(result).to eq(text: "", input_tokens: 0, output_tokens: 0, stop_reason: "")
    end

    it "returns max context tokens" do
      expect(adapter.max_context_tokens).to eq(128_000)
    end
  end
end
