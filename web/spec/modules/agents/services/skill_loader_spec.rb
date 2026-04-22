# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agents::SkillLoader, spec: "specifications/system/agent-runner/concept.md#skill-loader" do
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) }

  def write_skill(filename, content)
    path = File.join(tmp_dir, filename)
    File.write(path, content)
    path
  end

  describe ".call" do
    context "when source_ref is nil or blank" do
      it "returns empty result for nil" do
        result = described_class.call(nil)
        expect(result.body).to eq("")
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
        expect(result.principles).to eq([])
      end

      it "returns empty result for empty string" do
        result = described_class.call("")
        expect(result.body).to eq("")
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
        expect(result.principles).to eq([])
      end
    end

    context "when file does not exist" do
      it "returns empty result" do
        result = described_class.call("/nonexistent/path/skill.md")
        expect(result.body).to eq("")
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
        expect(result.principles).to eq([])
      end
    end

    context "with a valid skill file with tools frontmatter" do
      let(:path) do
        write_skill("build.md", <<~MD)
          ---
          name: build
          kind: loop
          tools:
            enrich:
              - git_diff
            callable:
              - read_file
              - write_file
          ---
          Execute one beat per iteration.
        MD
      end

      it "loads the instruction body" do
        result = described_class.call(path)
        expect(result.body).to eq("Execute one beat per iteration.")
      end

      it "parses enrich tools" do
        result = described_class.call(path)
        expect(result.enrich_tools).to eq(["git_diff"])
      end

      it "parses callable tools" do
        result = described_class.call(path)
        expect(result.callable_tools).to eq(["read_file", "write_file"])
      end
    end

    context "with a skill file that declares principles" do
      let(:path) do
        write_skill("build_with_principles.md", <<~MD)
          ---
          name: build
          kind: loop
          principles: [cost, coding, verification]
          ---
          Execute one beat per iteration.
        MD
      end

      it "parses principles" do
        result = described_class.call(path)
        expect(result.principles).to eq(["cost", "coding", "verification"])
      end
    end

    context "with a skill file that has no tools key" do
      let(:path) do
        write_skill("research.md", <<~MD)
          ---
          name: research
          kind: tool
          ---
          Collect sources and findings.
        MD
      end

      it "returns empty tool arrays" do
        result = described_class.call(path)
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
      end

      it "loads the body" do
        result = described_class.call(path)
        expect(result.body).to eq("Collect sources and findings.")
      end
    end

    context "with a skill file that has a flat tools array (not nested)" do
      let(:path) do
        write_skill("plan.md", <<~MD)
          ---
          name: plan
          tools: [analyse]
          ---
          Produce beats.
        MD
      end

      it "returns empty enrich and callable (flat array is not the nested format)" do
        result = described_class.call(path)
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
      end
    end

    context "with malformed YAML frontmatter" do
      let(:path) do
        write_skill("broken.md", <<~MD)
          ---
          name: [unclosed
          ---
          Body content here.
        MD
      end

      it "returns the raw content as body without raising" do
        result = described_class.call(path)
        expect(result.body).not_to be_empty
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
      end
    end

    context "with a file that has no frontmatter" do
      let(:path) do
        write_skill("plain.md", "Just plain content without frontmatter.")
      end

      it "returns the entire file as body" do
        result = described_class.call(path)
        expect(result.body).to eq("Just plain content without frontmatter.")
        expect(result.enrich_tools).to eq([])
        expect(result.callable_tools).to eq([])
      end
    end
  end
end
