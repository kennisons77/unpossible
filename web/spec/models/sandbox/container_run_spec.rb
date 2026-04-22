# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sandbox::ContainerRun, type: :model, spec: "specifications/system/sandbox/concept.md#container-run" do
  describe "validations" do
    it "is valid with all required fields" do
      run = build(:sandbox_container_run)
      expect(run).to be_valid
    end

    it "requires org_id" do
      run = build(:sandbox_container_run, org_id: nil)
      expect(run).not_to be_valid
      expect(run.errors[:org_id]).to be_present
    end

    it "validates status inclusion" do
      run = build(:sandbox_container_run, status: "invalid")
      expect(run).not_to be_valid
      expect(run.errors[:status]).to be_present
    end

    it "accepts all defined statuses" do
      Sandbox::ContainerRun::STATUSES.each do |s|
        run = build(:sandbox_container_run, status: s)
        expect(run).to be_valid, "expected status '#{s}' to be valid"
      end
    end

    it "requires image" do
      run = build(:sandbox_container_run, image: nil)
      expect(run).not_to be_valid
      expect(run.errors[:image]).to be_present
    end

    it "requires command" do
      run = build(:sandbox_container_run, command: nil)
      expect(run).not_to be_valid
      expect(run.errors[:command]).to be_present
    end
  end

  describe "agent_run_id nullable" do
    it "allows nil agent_run_id" do
      run = build(:sandbox_container_run, agent_run: nil)
      expect(run).to be_valid
    end

    it "accepts an agent_run association" do
      agent_run = create(:agents_agent_run)
      run = build(:sandbox_container_run, agent_run: agent_run)
      expect(run).to be_valid
    end
  end

  describe "#duration_ms" do
    it "computes duration from started_at and finished_at" do
      run = build(:sandbox_container_run,
        started_at: Time.zone.parse("2026-04-09 12:00:00"),
        finished_at: Time.zone.parse("2026-04-09 12:00:05"))
      expect(run.duration_ms).to eq(5000)
    end

    it "returns nil when started_at is nil" do
      run = build(:sandbox_container_run, started_at: nil, finished_at: Time.current)
      expect(run.duration_ms).to be_nil
    end

    it "returns nil when finished_at is nil" do
      run = build(:sandbox_container_run, started_at: Time.current, finished_at: nil)
      expect(run.duration_ms).to be_nil
    end
  end
end
