# frozen_string_literal: true

default_org = ENV.fetch("DEFAULT_ORG_ID", "00000000-0000-0000-0000-000000000001")

Ledger::Project.find_or_create_by!(name: "unpossible", org_id: default_org) do |p|
  p.description = "An evolving platform for AI-assisted software development."
end
