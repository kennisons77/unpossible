# frozen_string_literal: true

class Document < ApplicationRecord
  STAGES = %i[acquired categorized identified normalized stored enriched].freeze

  enum(:stage, STAGES.each_with_object({}).with_index { |(stage, hash), i| hash[stage] = i })

  belongs_to :owner, class_name: "User"
  belongs_to :concern, optional: true
  has_many :document_fields, dependent: :destroy
  has_one_attached :original_blob

  validates :stage, presence: true

  scope :needing_review, -> { where(review_required: true) }
end
