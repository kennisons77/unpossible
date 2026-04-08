# frozen_string_literal: true

module Ledger
  class Node < ApplicationRecord
    self.table_name = "ledger_nodes"

    KINDS = %w[question answer].freeze
    ANSWER_TYPES = %w[terminal generative].freeze
    SCOPES = %w[intent code deployment ui interaction].freeze
    # level sub-divides intent-scoped nodes:
    #   ideology    — "Why does this exist?"          (pitch, principle, mission)
    #   concept     — "What does it do?"              (feature, PRD)
    #   practice    — "What patterns does this invoke?" (practice doc, convention)
    #   specification — "How exactly is it built?"    (spec, plan, beat)
    LEVELS = %w[ideology concept practice specification].freeze
    AUTHORS = %w[human agent system].freeze
    RESOLUTIONS = %w[done duplicate deferred wont_do].freeze

    STATUSES = %w[proposed refining in_review accepted in_progress blocked closed].freeze

    # Statuses permitted per scope/level combination.
    # Keys are scope values; intent uses level sub-keys.
    PERMITTED_STATUSES = {
      "intent"      => %w[proposed refining in_review accepted blocked closed],
      "code"        => %w[proposed refining in_review accepted in_progress blocked closed],
      "deployment"  => %w[proposed in_progress blocked closed],
      "ui"          => %w[proposed in_progress blocked closed],
      "interaction" => %w[proposed in_progress blocked closed]
    }.freeze

    has_many :audit_events, class_name: "Ledger::NodeAuditEvent", foreign_key: :node_id,
                            dependent: :restrict_with_error

    validates :kind,        inclusion: { in: KINDS }
    validates :scope,       inclusion: { in: SCOPES }
    validates :level,       inclusion: { in: LEVELS }, allow_nil: true
    validates :author,      inclusion: { in: AUTHORS }
    validates :body,        presence: true
    validates :org_id,      presence: true
    validates :recorded_at, presence: true
    validates :stable_ref,  presence: true
    validates :answer_type, inclusion: { in: ANSWER_TYPES }, allow_nil: true
    validates :status,      inclusion: { in: STATUSES }, allow_nil: true
    validates :resolution,  inclusion: { in: RESOLUTIONS }, allow_nil: true

    validate :answer_type_only_for_answers
    validate :status_only_for_questions
    validate :answer_immutable_after_creation, on: :update
    validate :level_only_for_intent
    validate :status_permitted_for_scope, if: -> { status.present? && scope.present? }

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

      immutable = %w[body kind answer_type scope author]
      errors.add(:base, "answer nodes are immutable after creation") if immutable.any? { |f| send(:"#{f}_changed?") }
    end

    def level_only_for_intent
      return unless level.present? && scope != "intent"

      errors.add(:level, "only valid on intent-scoped nodes")
    end

    def status_permitted_for_scope
      permitted = PERMITTED_STATUSES[scope] || STATUSES
      return if permitted.include?(status)

      errors.add(:status, "'#{status}' is not permitted for scope '#{scope}'")
    end

    def set_defaults
      self.recorded_at ||= Time.current
      self.status      ||= "proposed" if kind == "question"
    end
  end
end
