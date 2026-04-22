# frozen_string_literal: true

require "rails_helper"
require "net/http"

RSpec.describe "call_provider", spec: "specifications/system/agent-runner/concept.md#provider-adapter" do
  def with_env(vars)
    old = vars.transform_keys(&:to_s).transform_values { |_| ENV[_] }
    vars.each { |k, v| ENV[k.to_s] = v }
    yield
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  let(:prompt_claude) do
    { model: "claude-sonnet-4-20250514", system: "be concise", messages: [{ role: "user", content: "hello" }] }
  end
  let(:prompt_openai) do
    { model: "gpt-4o", messages: [{ role: "system", content: "be concise" }, { role: "user", content: "hello" }] }
  end
  let(:prompt_kiro) do
    { model: "kiro", system: "be concise", messages: [{ role: "user", content: "hello" }] }
  end

  describe Agents::ClaudeAdapter do
    subject(:adapter) { described_class.new }

    let(:success_body) do
      { "content" => [{ "text" => "Hi there" }], "usage" => { "input_tokens" => 10, "output_tokens" => 3 }, "stop_reason" => "end_turn" }.to_json
    end

    it "POSTs to the Anthropic messages endpoint" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      adapter.call_provider(prompt_claude)

      expect(stub).to have_been_requested
    end

    it "sends the correct Content-Type and anthropic-version headers" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "Content-Type" => "application/json", "anthropic-version" => "2023-06-01" })
        .to_return(status: 200, body: success_body)

      adapter.call_provider(prompt_claude)

      expect(stub).to have_been_requested
    end

    it "sends the API key from ANTHROPIC_API_KEY env var" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "x-api-key" => "test-key" })
        .to_return(status: 200, body: success_body)

      with_env("ANTHROPIC_API_KEY" => "test-key") { adapter.call_provider(prompt_claude) }

      expect(stub).to have_been_requested
    end

    it "returns parsed JSON response hash" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: success_body)

      result = adapter.call_provider(prompt_claude)

      expect(result).to eq(JSON.parse(success_body))
    end

    it "returns error hash on network error without raising" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_raise(Net::ReadTimeout)

      result = nil
      expect { result = adapter.call_provider(prompt_claude) }.not_to raise_error
      expect(result).to have_key("error")
    end

    it "does not include the API key in error messages" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_raise(Net::ReadTimeout)

      result = with_env("ANTHROPIC_API_KEY" => "super-secret-key") { adapter.call_provider(prompt_claude) }

      expect(result.to_s).not_to include("super-secret-key")
    end
  end

  describe Agents::OpenAiAdapter do
    subject(:adapter) { described_class.new }

    let(:success_body) do
      { "choices" => [{ "message" => { "content" => "Hi" }, "finish_reason" => "stop" }], "usage" => { "prompt_tokens" => 10, "completion_tokens" => 2 } }.to_json
    end

    it "POSTs to the OpenAI chat completions endpoint" do
      stub = stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      adapter.call_provider(prompt_openai)

      expect(stub).to have_been_requested
    end

    it "sends Authorization Bearer header from OPENAI_API_KEY env var" do
      stub = stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .with(headers: { "Authorization" => "Bearer test-openai-key" })
        .to_return(status: 200, body: success_body)

      with_env("OPENAI_API_KEY" => "test-openai-key") { adapter.call_provider(prompt_openai) }

      expect(stub).to have_been_requested
    end

    it "returns parsed JSON response hash" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(status: 200, body: success_body)

      result = adapter.call_provider(prompt_openai)

      expect(result).to eq(JSON.parse(success_body))
    end

    it "returns error hash on network error without raising" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_raise(Net::ReadTimeout)

      result = nil
      expect { result = adapter.call_provider(prompt_openai) }.not_to raise_error
      expect(result).to have_key("error")
    end

    it "does not include the API key in error messages" do
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_raise(Net::ReadTimeout)

      result = with_env("OPENAI_API_KEY" => "super-secret-openai") { adapter.call_provider(prompt_openai) }

      expect(result.to_s).not_to include("super-secret-openai")
    end
  end

  describe Agents::KiroAdapter do
    subject(:adapter) { described_class.new }

    let(:success_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }
    let(:failure_status) { instance_double(Process::Status, success?: false, exitstatus: 1) }

    it "invokes kiro-cli with correct arguments" do
      allow(Open3).to receive(:capture3)
        .with("kiro-cli", "chat", "--no-interactive", "--trust-all-tools", "--", anything)
        .and_return(["response text", "", success_status])

      adapter.call_provider(prompt_kiro)

      expect(Open3).to have_received(:capture3)
        .with("kiro-cli", "chat", "--no-interactive", "--trust-all-tools", "--", anything)
    end

    it "returns response hash with content text on success" do
      allow(Open3).to receive(:capture3).and_return(["response text", "", success_status])

      result = adapter.call_provider(prompt_kiro)

      expect(result.dig("content", 0, "text")).to eq("response text")
      expect(result["stop_reason"]).to eq("end_turn")
    end

    it "returns error hash on non-zero exit without raising" do
      allow(Open3).to receive(:capture3).and_return(["", "error output", failure_status])

      result = nil
      expect { result = adapter.call_provider(prompt_kiro) }.not_to raise_error
      expect(result).to have_key("error")
    end

    it "returns error hash when kiro-cli is not found without raising" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT, "kiro-cli")

      result = nil
      expect { result = adapter.call_provider(prompt_kiro) }.not_to raise_error
      expect(result).to have_key("error")
    end

    it "includes system and messages in the CLI input" do
      captured_input = nil
      allow(Open3).to receive(:capture3) do |*args|
        captured_input = args.last
        ["ok", "", success_status]
      end

      adapter.call_provider(prompt_kiro)

      expect(captured_input).to include("be concise")
      expect(captured_input).to include("hello")
    end
  end
end
