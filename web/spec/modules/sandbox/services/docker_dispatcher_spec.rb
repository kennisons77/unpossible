# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sandbox::DockerDispatcher, type: :service do
  let(:dispatcher) { described_class.new(timeout: 5) }
  let(:org_id) { SecureRandom.uuid }

  def stub_capture3(stdout: "", stderr: "", exit_code: 0)
    status = instance_double(Process::Status, exitstatus: exit_code)
    allow(Open3).to receive(:capture3).and_return([stdout, stderr, status])
  end

  describe "#dispatch" do
    it "returns exit_code 0 and stdout on success" do
      stub_capture3(stdout: "hello world\n", exit_code: 0)

      result = dispatcher.dispatch(image: "ruby:3.3-slim", command: ["echo", "hello world"], org_id: org_id)

      expect(result[:exit_code]).to eq(0)
      expect(result[:stdout]).to eq("hello world\n")
      expect(result[:stderr]).to eq("")
    end

    it "returns non-zero exit_code without raising on failure" do
      stub_capture3(stderr: "not found\n", exit_code: 1)

      result = dispatcher.dispatch(image: "ruby:3.3-slim", command: ["false"], org_id: org_id)

      expect(result[:exit_code]).to eq(1)
      expect(result[:stderr]).to include("not found")
    end

    it "does not log env vars containing Secret values" do
      stub_capture3(exit_code: 0)
      secret = Secret.new("sk-supersecret")

      log_output = StringIO.new
      allow(Rails.logger).to receive(:info) { |msg| log_output.write(msg) }

      dispatcher.dispatch(image: "ruby:3.3-slim", command: ["env"], env: { "API_KEY" => secret, "PLAIN" => "visible" }, org_id: org_id)

      expect(log_output.string).to include("[REDACTED]")
      expect(log_output.string).not_to include("sk-supersecret")
      expect(log_output.string).to include("visible")
    end

    it "kills container and returns non-zero exit on timeout" do
      allow(Open3).to receive(:capture3) { raise Timeout::Error }

      short_dispatcher = described_class.new(timeout: 0.1)
      result = short_dispatcher.dispatch(image: "ruby:3.3-slim", command: ["sleep", "999"], org_id: org_id)

      expect(result[:exit_code]).to eq(137)
      expect(result[:stderr]).to include("timeout")
    end

    it "creates a ContainerRun record and updates it with final status" do
      stub_capture3(stdout: "ok\n", exit_code: 0)

      expect {
        dispatcher.dispatch(image: "ruby:3.3-slim", command: ["echo", "ok"], org_id: org_id)
      }.to change(Sandbox::ContainerRun, :count).by(1)

      run = Sandbox::ContainerRun.last
      expect(run.org_id).to eq(org_id)
      expect(run.status).to eq("complete")
      expect(run.exit_code).to eq(0)
      expect(run.stdout).to eq("ok\n")
      expect(run.started_at).to be_present
      expect(run.finished_at).to be_present
      expect(run.duration_ms).to be >= 0
    end

    it "passes command as argument array — no shell interpolation" do
      stub_capture3(exit_code: 0)

      dispatcher.dispatch(image: "ruby:3.3-slim", command: ["echo", "hello; rm -rf /"], org_id: org_id)

      expect(Open3).to have_received(:capture3).with(
        "docker", "run", "--rm", "ruby:3.3-slim", "echo", "hello; rm -rf /"
      )
    end
  end
end
