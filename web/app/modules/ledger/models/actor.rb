# frozen_string_literal: true

module Ledger
  class Actor < ApplicationRecord
    self.table_name = "ledger_actors"

    belongs_to :actor_profile, class_name: "Ledger::ActorProfile"
    belongs_to :node, class_name: "Ledger::Node"
  end
end
