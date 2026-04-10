# frozen_string_literal: true

class SeedUnpossibleProjectRecord < ActiveRecord::Migration[8.0]
  def up
    org = ENV.fetch("DEFAULT_ORG_ID", "00000000-0000-0000-0000-000000000001")

    return if execute("SELECT 1 FROM ledger_projects WHERE name = 'unpossible' AND org_id = #{quote(org)} LIMIT 1").any?

    execute <<~SQL
      INSERT INTO ledger_projects (id, name, description, org_id, created_at, updated_at)
      VALUES (gen_random_uuid(), 'unpossible', 'An evolving platform for AI-assisted software development.', #{quote(org)}, NOW(), NOW())
    SQL
  end

  def down
    execute "DELETE FROM ledger_projects WHERE name = 'unpossible'"
  end
end
