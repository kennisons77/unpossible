# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentField do
  describe "associations" do
    it { is_expected.to belong_to(:document) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:field_name) }
    it { is_expected.to validate_presence_of(:source) }
  end

  describe "source enum" do
    it "supports llm source" do
      field = build(:document_field, source: :llm)
      expect(field).to be_llm
    end

    it "supports ocr source" do
      field = build(:document_field, source: :ocr)
      expect(field).to be_ocr
    end

    it "supports human source" do
      field = build(:document_field, source: :human)
      expect(field).to be_human
    end

    it "rejects invalid source values" do
      expect { build(:document_field, source: :invalid) }.to raise_error(ArgumentError)
    end
  end

  describe "persistence" do
    it "persists with each valid source value" do
      document = create(:document)

      %i[llm ocr human].each do |source_type|
        field = create(:document_field, document: document, source: source_type)
        expect(field).to be_persisted
      end
    end
  end
end
