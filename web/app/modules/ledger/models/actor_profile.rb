# frozen_string_literal: true

module Ledger
  class ActorProfile < ApplicationRecord
    self.table_name = "ledger_actor_profiles"

    validates :name, presence: true
    validates :provider, presence: true
    validates :model, presence: true
    validates :org_id, presence: true
  end
end
