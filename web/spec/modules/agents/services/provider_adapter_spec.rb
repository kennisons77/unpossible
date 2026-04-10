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
      expect { adapter.build_prompt([]) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for parse_response" do
      expect { adapter.parse_response({}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for max_context_tokens" do
      expect { adapter.max_context_tokens }.to raise_error(NotImplementedError)
    end
  end

  describe Agents::ClaudeAdapter do
    subject(:adapter) { described_class.new }

    it "builds a prompt with claude model" do
      result = adapter.build_prompt([{ role: "user", content: "hello" }])
      expect(result[:model]).to eq("claude-sonnet-4-20250514")
      expect(result[:messages]).to eq([{ role: "user", content: "hello" }])
    end

    it "parses response from content array" do
      raw = { "content" => [{ "text" => "response text" }] }
      expect(adapter.parse_response(raw)).to eq("response text")
    end

    it "returns max context tokens" do
      expect(adapter.max_context_tokens).to eq(200_000)
    end
  end

  describe Agents::KiroAdapter do
    subject(:adapter) { described_class.new }

    it "builds a prompt with kiro model" do
      result = adapter.build_prompt([{ role: "user", content: "hello" }])
      expect(result[:model]).to eq("kiro")
    end

    it "parses response from content array" do
      raw = { "content" => [{ "text" => "response text" }] }
      expect(adapter.parse_response(raw)).to eq("response text")
    end

    it "returns max context tokens" do
      expect(adapter.max_context_tokens).to eq(200_000)
    end
  end

  describe Agents::OpenAiAdapter do
    subject(:adapter) { described_class.new }

    it "builds a prompt with gpt-4o model" do
      result = adapter.build_prompt([{ role: "user", content: "hello" }])
      expect(result[:model]).to eq("gpt-4o")
    end

    it "parses response from choices array" do
      raw = { "choices" => [{ "message" => { "content" => "response text" } }] }
      expect(adapter.parse_response(raw)).to eq("response text")
    end

    it "returns max context tokens" do
      expect(adapter.max_context_tokens).to eq(128_000)
    end
  end
end
