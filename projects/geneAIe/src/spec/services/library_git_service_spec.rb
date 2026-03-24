# frozen_string_literal: true

require "rails_helper"

RSpec.describe LibraryGitService do
  let(:library_path) { Dir.mktmpdir("sovereign-library-test") }
  let(:service) { described_class.new(library_path: library_path) }
  let(:user) { create(:user) }
  let(:concern) { create(:concern, owner: user, name: "Financial") }
  let(:document) do
    create(:document, :categorized, owner: user, concern: concern, document_type: "utility_bill")
  end
  let(:content) { "---\ntitle: Test Document\n---\nBody content here.\n" }

  after { FileUtils.rm_rf(library_path) }

  describe "#write_and_commit" do
    it "creates the file at the correct nested path" do
      relative_path = service.write_and_commit(document: document, content: content)

      expect(relative_path).to eq("financial/utility_bill/#{document.id}.md")
      expect(File.read(File.join(library_path, relative_path))).to eq(content)
    end

    it "creates missing subdirectories" do
      service.write_and_commit(document: document, content: content)

      expect(File.directory?(File.join(library_path, "financial", "utility_bill"))).to be true
    end

    it "commits with the expected message format" do
      freeze_time do
        service.write_and_commit(document: document, content: content, source: "llm")

        log = `git -C #{library_path} log --format=%s -1`.strip
        expected = "doc:#{document.id} stage:categorized source:llm at:#{Time.current.iso8601}"
        expect(log).to eq(expected)
      end
    end

    it "handles first commit in an empty repo" do
      expect { service.write_and_commit(document: document, content: content) }.not_to raise_error

      commit_count = `git -C #{library_path} rev-list --count HEAD`.strip.to_i
      expect(commit_count).to eq(1)
    end

    it "updates an existing file and creates a new commit" do
      service.write_and_commit(document: document, content: content)
      updated_content = "---\ntitle: Updated Document\n---\nUpdated body.\n"
      service.write_and_commit(document: document, content: updated_content, source: "human")

      commit_count = `git -C #{library_path} rev-list --count HEAD`.strip.to_i
      expect(commit_count).to eq(2)

      file_path = File.join(library_path, "financial/utility_bill/#{document.id}.md")
      expect(File.read(file_path)).to eq(updated_content)
    end

    context "when document has no concern" do
      let(:document) { create(:document, owner: user, concern: nil) }

      it "uses uncategorized as the concern directory" do
        relative_path = service.write_and_commit(document: document, content: content)

        expect(relative_path).to start_with("uncategorized/")
      end
    end

    context "when document has no document_type" do
      let(:document) { create(:document, owner: user, concern: concern, document_type: nil) }

      it "uses unknown as the document_type directory" do
        relative_path = service.write_and_commit(document: document, content: content)

        expect(relative_path).to include("/unknown/")
      end
    end

    context "when concern name has special characters" do
      let(:concern) { create(:concern, owner: user, name: "Health & Medical") }

      it "sanitizes the directory name" do
        relative_path = service.write_and_commit(document: document, content: content)

        expect(relative_path).to start_with("health_medical/")
      end
    end

    it "records the correct source in the commit message" do
      service.write_and_commit(document: document, content: content, source: "ocr")

      log = `git -C #{library_path} log --format=%s -1`.strip
      expect(log).to include("source:ocr")
    end
  end
end
