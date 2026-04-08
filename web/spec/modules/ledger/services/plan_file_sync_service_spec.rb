# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::PlanFileSyncService do
  let(:org_id) { SecureRandom.uuid }

  def sync(content)
    Tempfile.create(["plan", ".md"]) do |f|
      f.write(content)
      f.flush
      described_class.sync(plan_path: f.path, org_id: org_id)
    end
  end

  def node(ref)
    Ledger::Node.find_by(stable_ref: ref, org_id: org_id)
  end

  describe "UAT-4: plan file sync" do
    it "creates an open node for an unchecked item" do
      sync("- [ ] Do something <!-- ref: task-001 -->")
      expect(node("task-001")).to have_attributes(status: "proposed", kind: "question", scope: "code")
    end

    it "creates a closed node for a checked item" do
      sync("- [x] Done thing <!-- ref: task-002 -->")
      expect(node("task-002")).to have_attributes(status: "closed")
    end

    it "skips lines without a ref comment" do
      sync("- [ ] No ref here\n- [x] Also no ref")
      expect(Ledger::Node.where(org_id: org_id).count).to eq(0)
    end

    it "is idempotent — re-sync does not create duplicates" do
      content = "- [ ] Task <!-- ref: task-003 -->"
      sync(content)
      sync(content)
      expect(Ledger::Node.where(stable_ref: "task-003", org_id: org_id).count).to eq(1)
    end

    it "transitions unchecked → closed when item is checked on re-sync" do
      sync("- [ ] Task <!-- ref: task-004 -->")
      expect(node("task-004").status).to eq("proposed")

      sync("- [x] Task <!-- ref: task-004 -->")
      expect(node("task-004").status).to eq("closed")
    end

    it "transitions closed → open when item is unchecked on re-sync" do
      sync("- [x] Task <!-- ref: task-005 -->")
      expect(node("task-005").status).to eq("closed")

      sync("- [ ] Task <!-- ref: task-005 -->")
      expect(node("task-005").status).to eq("proposed")
    end

    it "increments version when status changes" do
      sync("- [ ] Task <!-- ref: task-006 -->")
      initial_version = node("task-006").version

      sync("- [x] Task <!-- ref: task-006 -->")
      expect(node("task-006").version).to eq(initial_version + 1)
    end

    it "flags removed items as orphaned (resolution: deferred)" do
      sync("- [ ] Task A <!-- ref: task-007 -->\n- [ ] Task B <!-- ref: task-008 -->")
      expect(node("task-007")).to be_present
      expect(node("task-008")).to be_present

      sync("- [ ] Task A <!-- ref: task-007 -->")
      expect(node("task-008").resolution).to eq("deferred")
    end

    it "does not delete orphaned nodes" do
      sync("- [ ] Task <!-- ref: task-009 -->")
      sync("")
      expect(node("task-009")).to be_present
    end

    it "does not re-flag already-deferred orphans" do
      sync("- [ ] Task <!-- ref: task-010 -->")
      sync("")
      expect { sync("") }.not_to raise_error
      expect(node("task-010").resolution).to eq("deferred")
    end

    it "does not affect nodes from other orgs" do
      other_org = SecureRandom.uuid
      create(:ledger_node, stable_ref: "task-011", org_id: other_org, scope: "code", author: "system")

      sync("- [ ] Something else <!-- ref: task-012 -->")
      expect(Ledger::Node.find_by(stable_ref: "task-011", org_id: other_org).resolution).to be_nil
    end
  end
end
