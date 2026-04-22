# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agents::ContextRetriever, spec: "specifications/system/agent-runner/concept.md#context-retrieval" do
  let(:tmp_dir) { Dir.mktmpdir }

  before do
    allow(described_class).to receive(:resolve_path) { |name| File.join(tmp_dir, "#{name}.md") }
  end

  after { FileUtils.remove_entry(tmp_dir) }

  def write_practice(name, content)
    File.write(File.join(tmp_dir, "#{name}.md"), content)
  end

  describe ".call" do
    context "when principles is nil or empty" do
      it "returns empty array for nil" do
        expect(described_class.call(nil)).to eq([])
      end

      it "returns empty array for empty array" do
        expect(described_class.call([])).to eq([])
      end
    end

    context "when a declared practice file exists" do
      before { write_practice("coding", "# Coding\nDo good things.") }

      it "returns the file content" do
        result = described_class.call(["coding"])
        expect(result).to eq(["# Coding\nDo good things."])
      end
    end

    context "when multiple practice files are declared" do
      before do
        write_practice("cost", "# Cost")
        write_practice("coding", "# Coding")
      end

      it "returns content for each declared file in order" do
        result = described_class.call(["cost", "coding"])
        expect(result).to eq(["# Cost", "# Coding"])
      end
    end

    context "when a declared practice file is missing" do
      it "skips the missing file without raising" do
        expect { described_class.call(["nonexistent"]) }.not_to raise_error
      end

      it "returns empty array when all files are missing" do
        expect(described_class.call(["nonexistent"])).to eq([])
      end

      it "returns only the files that exist when some are missing" do
        write_practice("cost", "# Cost")
        result = described_class.call(["cost", "nonexistent"])
        expect(result).to eq(["# Cost"])
      end
    end
  end
end
