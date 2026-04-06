# frozen_string_literal: true

module Ledger
  class Node < ApplicationRecord
    self.table_name = "ledger_nodes"

    KINDS = %w[question answer].freeze
    ANSWER_TYPES = %w[terminal generative].freeze
    SCOPES = %w[intent code deployment ui interaction].freeze
    AUTHORS = %w[human agent system].freeze
    STATUSES = %w[open in_progress blocked closed].freeze
    RESOLUTIONS = %w[done duplicate deferred wont_do icebox].freeze
    ACCEPTED_VALUES = %w[true false pending].freeze

    validates :kind, inclusion: { in: KINDS }
    validates :scope, inclusion: { in: SCOPES }
    validates :author, inclusion: { in: AUTHORS }
    validates :body, presence: true
    validates :org_id, presence: true
    validates :recorded_at, presence: true
    validates :stable_ref, presence: true
    validates :answer_type, inclusion: { in: ANSWER_TYPES }, allow_nil: true
    validates :status, inclusion: { in: STATUSES }, allow_nil: true
    validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true
    validates :accepted, inclusion: { in: ACCEPTED_VALUES }, allow_nil: true

    validate :answer_type_only_for_answers
    validate :status_only_for_questions
    validate :answer_immutable_after_creation, on: :update

    before_validation :set_defaults, on: :create

    private

    def answer_type_only_for_answers
      return unless answer_type.present? && kind != "answer"

      errors.add(:answer_type, "only valid on answer nodes")
    end

    def status_only_for_questions
      return unless status.present? && kind != "question"

      errors.add(:status, "only valid on question nodes")
    end

    def answer_immutable_after_creation
      return unless kind == "answer"

      immutable_fields = %w[body kind answer_type scope author]
      changed_immutable = immutable_fields.select { |f| send(:"#{f}_changed?") }
      errors.add(:base, "answer nodes are immutable after creation") if changed_immutable.any?
    end

    def set_defaults
      self.recorded_at ||= Time.current
      self.accepted ||= "pending" if kind == "answer"
    end
  end
end
