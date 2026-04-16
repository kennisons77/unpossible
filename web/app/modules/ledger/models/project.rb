# frozen_string_literal: true

module Ledger
  class Project < ApplicationRecord
    self.table_name = "ledger_projects"

    has_many :nodes, class_name: "Ledger::Node", foreign_key: :project_id, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: { scope: :org_id }
    validates :org_id, presence: true
  end
end
