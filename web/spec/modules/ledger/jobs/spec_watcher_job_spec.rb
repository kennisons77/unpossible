# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe Ledger::SpecWatcherJob, type: :job do
  around do |example|
    Dir.mktmpdir("spec_watcher") do |tmpdir|
      FileUtils.mkdir_p(File.join(tmpdir, "specs", "system"))
      @specs_root = tmpdir
      example.run
    end
  end

  # Suppress re-enqueue side-effect in all examples
  before do
    allow(described_class).to receive(:set).and_return(double(perform_later: nil))
  end

  def write_spec(rel_path, content = "# Spec\n\nSome content.")
    abs = File.join(@specs_root, rel_path)
    FileUtils.mkdir_p(File.dirname(abs))
    File.write(abs, content)
    abs
  end

  def run_job
    described_class.new.perform(specs_root: @specs_root)
  end

  def node_for(rel_path)
    ref = "spec:#{Digest::SHA256.hexdigest(rel_path)}"
    Ledger::Node.find_by!(stable_ref: ref)
  end

  describe "new file → creates Node" do
    it "creates a question node with scope: intent and status: open" do
      write_spec("specs/system/my-feature.md")
      expect { run_job }.to change(Ledger::Node, :count).by(1)

      node = node_for("specs/system/my-feature.md")
      expect(node.kind).to eq("question")
      expect(node.scope).to eq("intent")
      expect(node.status).to eq("open")
      expect(node.author).to eq("system")
      expect(node.spec_path).to eq("specs/system/my-feature.md")
    end

    it "is idempotent — running twice does not create a duplicate" do
      write_spec("specs/system/my-feature.md")
      run_job
      expect { run_job }.not_to change(Ledger::Node, :count)
    end

    it "uses a deterministic stable_ref based on path" do
      write_spec("specs/system/my-feature.md")
      run_job
      expected_ref = "spec:#{Digest::SHA256.hexdigest('specs/system/my-feature.md')}"
      expect(Ledger::Node.find_by(stable_ref: expected_ref)).not_to be_nil
    end
  end

  describe "changed file → parses status header and applies transition" do
    before do
      write_spec("specs/system/feature.md", "# Feature\n\nContent.")
      run_job
    end

    it "transitions status when a valid <!-- status: X --> header is present" do
      node = node_for("specs/system/feature.md")
      write_spec("specs/system/feature.md", "<!-- status: in_progress -->\n# Feature\n\nContent.")
      expect { run_job }.to change { node.reload.status }.from("open").to("in_progress")
    end

    it "does not change status when header is absent" do
      node = node_for("specs/system/feature.md")
      write_spec("specs/system/feature.md", "# Feature\n\nUpdated content, no header.")
      expect { run_job }.not_to change { node.reload.status }
    end

    it "does not change status when header value is already current" do
      node = node_for("specs/system/feature.md")
      write_spec("specs/system/feature.md", "<!-- status: open -->\n# Feature")
      expect { run_job }.not_to change { node.reload.status }
    end

    it "ignores unknown status values in the header" do
      node = node_for("specs/system/feature.md")
      write_spec("specs/system/feature.md", "<!-- status: bogus -->\n# Feature")
      expect { run_job }.not_to change { node.reload.status }
    end
  end

  describe "deleted file → sets resolution: deferred" do
    it "marks the node deferred when the file is removed" do
      write_spec("specs/system/gone.md")
      run_job
      node = node_for("specs/system/gone.md")

      File.delete(File.join(@specs_root, "specs/system/gone.md"))
      run_job

      expect(node.reload.resolution).to eq("deferred")
    end

    it "is idempotent — does not error if already deferred" do
      write_spec("specs/system/gone.md")
      run_job
      node = node_for("specs/system/gone.md")
      File.delete(File.join(@specs_root, "specs/system/gone.md"))
      run_job
      expect { run_job }.not_to raise_error
      expect(node.reload.resolution).to eq("deferred")
    end
  end

  describe "git revert → sets conflict: true, never auto-resolves" do
    it "sets conflict: true when disk content matches HEAD~1 but not HEAD" do
      write_spec("specs/system/reverted.md", "# Original")
      run_job
      node = node_for("specs/system/reverted.md")

      allow_any_instance_of(described_class).to receive(:git_revert?).and_return(true)
      write_spec("specs/system/reverted.md", "# Reverted content")
      run_job

      expect(node.reload.conflict).to be(true)
    end

    it "does not auto-resolve a node already in conflict" do
      write_spec("specs/system/reverted.md", "# Original")
      run_job
      node = node_for("specs/system/reverted.md")
      node.update!(conflict: true)

      allow_any_instance_of(described_class).to receive(:git_revert?).and_return(true)
      write_spec("specs/system/reverted.md", "<!-- status: closed -->\n# Reverted")
      run_job

      expect(node.reload.status).to eq("open")
      expect(node.reload.conflict).to be(true)
    end
  end

  describe "Knowledge::IndexerJob enqueued after any change" do
    before do
      stub_const("Knowledge::IndexerJob", Class.new do
        def self.perform_later(*); end
      end)
    end

    it "enqueues IndexerJob for a newly created node" do
      write_spec("specs/system/new.md")
      expect(Knowledge::IndexerJob).to receive(:perform_later).once
      run_job
    end

    it "enqueues IndexerJob when a status transition occurs" do
      write_spec("specs/system/feature.md")
      run_job
      write_spec("specs/system/feature.md", "<!-- status: in_progress -->\n# Feature")
      expect(Knowledge::IndexerJob).to receive(:perform_later).once
      run_job
    end

    it "does not enqueue IndexerJob when nothing changed" do
      write_spec("specs/system/feature.md")
      run_job
      expect(Knowledge::IndexerJob).not_to receive(:perform_later)
      run_job
    end
  end
end
