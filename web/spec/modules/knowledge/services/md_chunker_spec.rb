# frozen_string_literal: true

require "rails_helper"

RSpec.describe Knowledge::MdChunker do
  describe ".chunk" do
    it "splits markdown into paragraph-level chunks" do
      text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
      result = described_class.chunk(text)

      expect(result.length).to eq(3)
      expect(result[0][:content]).to eq("First paragraph.")
      expect(result[1][:content]).to eq("Second paragraph.")
      expect(result[2][:content]).to eq("Third paragraph.")
    end

    it "preserves section headers with their content" do
      text = "# Header One\n\nSome content under header one.\n\n## Header Two\n\nContent under header two."
      result = described_class.chunk(text)

      header_chunks = result.select { |c| c[:content].start_with?("#") }
      expect(header_chunks).not_to be_empty

      h2_chunk = result.find { |c| c[:content].include?("## Header Two") }
      expect(h2_chunk[:content]).to include("Content under header two")
    end

    it "returns chunk_index for each chunk" do
      text = "First.\n\nSecond.\n\nThird."
      result = described_class.chunk(text)

      expect(result.map { |c| c[:chunk_index] }).to eq([0, 1, 2])
    end

    it "returns empty array for empty input" do
      expect(described_class.chunk("")).to eq([])
      expect(described_class.chunk(nil)).to eq([])
      expect(described_class.chunk("   \n\n  ")).to eq([])
    end
  end
end
