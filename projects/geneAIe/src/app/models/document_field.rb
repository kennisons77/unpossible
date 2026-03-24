# frozen_string_literal: true

class DocumentField < ApplicationRecord
  enum :source, { llm: 0, ocr: 1, human: 2 }

  belongs_to :document

  validates :field_name, presence: true
  validates :source, presence: true
end
