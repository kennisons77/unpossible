# frozen_string_literal: true

# Content is cleared by TurnContentGcJob when purged_at is set.
# The turn record is retained for audit; only the content is removed.
class AllowNullContentOnAgentRunTurns < ActiveRecord::Migration[8.0]
  def change
    change_column_null :agents_agent_run_turns, :content, true
  end
end
