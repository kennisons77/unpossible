# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agents::EnrichmentRunner, spec: "specifications/system/agent-runner/concept.md#enrichment" do
  let(:run) { create(:agents_agent_run, status: "running") }

  describe ".call" do
    context "with a known tool (git_diff)" do
      before do
        allow(described_class::TOOLS["git_diff"]).to receive(:call).and_return("diff output")
      end

      it "appends a tool_result turn for each tool" do
        expect { described_class.call(run, ["git_diff"]) }
          .to change { run.turns.where(kind: "tool_result").count }.by(1)
      end

      it "includes the tool name and output in the turn content" do
        described_class.call(run, ["git_diff"])
        expect(run.turns.last.content).to include("git_diff").and include("diff output")
      end

      it "returns the created turn records" do
        turns = described_class.call(run, ["git_diff"])
        expect(turns.length).to eq(1)
        expect(turns.first).to be_a(Agents::AgentRunTurn)
      end

      it "assigns sequential positions after existing turns" do
        run.turns.create!(position: 3, kind: "llm_response", content: "prior")
        described_class.call(run, ["git_diff"])
        tool_turn = Agents::AgentRunTurn.where(agent_run_id: run.id, kind: "tool_result").first
        expect(tool_turn.position).to eq(4)
      end
    end

    context "with multiple tools" do
      before do
        stub_const("Agents::EnrichmentRunner::TOOLS", {
          "tool_a" => -> { "result_a" },
          "tool_b" => -> { "result_b" }
        })
      end

      it "appends one turn per tool" do
        expect { described_class.call(run, %w[tool_a tool_b]) }
          .to change { run.turns.where(kind: "tool_result").count }.by(2)
      end
    end

    context "with an unknown tool name" do
      it "skips the unknown tool without raising" do
        expect { described_class.call(run, ["nonexistent_tool"]) }.not_to raise_error
      end

      it "appends no turns for unknown tools" do
        expect { described_class.call(run, ["nonexistent_tool"]) }
          .not_to change { run.turns.count }
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/unknown tool/)
        described_class.call(run, ["nonexistent_tool"])
      end
    end

    context "when a tool raises an error" do
      before do
        stub_const("Agents::EnrichmentRunner::TOOLS", {
          "failing_tool" => -> { raise "boom" }
        })
      end

      it "does not raise" do
        expect { described_class.call(run, ["failing_tool"]) }.not_to raise_error
      end

      it "appends no turn for the failed tool" do
        expect { described_class.call(run, ["failing_tool"]) }
          .not_to change { run.turns.count }
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/failed/)
        described_class.call(run, ["failing_tool"])
      end
    end

    context "with an empty tool list" do
      it "returns an empty array" do
        expect(described_class.call(run, [])).to eq([])
      end

      it "appends no turns" do
        expect { described_class.call(run, []) }.not_to change { run.turns.count }
      end
    end

    context "with nil tool list" do
      it "returns an empty array without raising" do
        expect { described_class.call(run, nil) }.not_to raise_error
      end
    end
  end
end
