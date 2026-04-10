# frozen_string_literal: true

require "rails_helper"

RSpec.describe Knowledge::EmbedderService do
  describe ".for" do
    around do |example|
      original = ENV["OPENAI_API_KEY"]
      ENV["OPENAI_API_KEY"] = "sk-test-key"
      example.run
    ensure
      ENV["OPENAI_API_KEY"] = original
    end

    it "returns OpenAiEmbedder for 'openai'" do
      expect(described_class.for("openai")).to be_a(Knowledge::OpenAiEmbedder)
    end

    it "raises NotImplementedError for 'ollama'" do
      expect { described_class.for("ollama") }.to raise_error(NotImplementedError, /ollama/)
    end

    it "raises NotImplementedError for unknown provider" do
      expect { described_class.for("unknown") }.to raise_error(NotImplementedError, /unknown/)
    end
  end

  describe "API key never appears in logs or error messages" do
    let(:api_key) { "sk-secret-test-key-12345" }

    around do |example|
      original = ENV["OPENAI_API_KEY"]
      ENV["OPENAI_API_KEY"] = api_key
      example.run
    ensure
      ENV["OPENAI_API_KEY"] = original
    end

    it "wraps API key in Secret so it never leaks via inspect" do
      embedder = described_class.for("openai")
      expect(embedder.inspect).not_to include(api_key)
    end

    it "Secret#to_s and inspect redact the value" do
      secret = Secret.new(api_key)
      expect(secret.to_s).to eq("[REDACTED]")
      expect(secret.inspect).to eq("[REDACTED]")
      expect(secret.expose).to eq(api_key)
    end
  end
end
