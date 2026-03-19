require 'rails_helper'

RSpec.describe Document do
  describe 'associations' do
    it { is_expected.to belong_to(:owner).class_name('User') }
    it { is_expected.to belong_to(:concern).optional }
    it { is_expected.to have_many(:document_fields).dependent(:destroy) }
    it { is_expected.to have_one_attached(:original_blob) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:stage) }
  end

  describe 'stage enum' do
    it 'defaults to acquired' do
      document = Document.new
      expect(document.stage).to eq('acquired')
    end

    it 'supports all six pipeline stages' do
      expected = %w[acquired categorized identified normalized stored enriched]
      expect(described_class.stages.keys).to eq(expected)
    end

    it 'provides query methods for each stage' do
      document = build(:document, stage: :categorized)
      expect(document).to be_categorized
    end
  end

  describe 'defaults' do
    it 'sets review_required to false' do
      document = Document.new
      expect(document.review_required).to be false
    end

    it 'initializes concern_tags as empty array' do
      document = Document.new
      expect(document.concern_tags).to eq([])
    end
  end

  describe 'concern_tags' do
    it 'stores and retrieves array values' do
      document = create(:document, concern_tags: %w[health legal])
      document.reload
      expect(document.concern_tags).to eq(%w[health legal])
    end
  end

  describe 'scopes' do
    describe '.needing_review' do
      let!(:review_doc) { create(:document, :needing_review) }
      let!(:normal_doc) { create(:document) }

      it 'returns only documents requiring review' do
        expect(described_class.needing_review).to eq([review_doc])
      end
    end
  end
end
