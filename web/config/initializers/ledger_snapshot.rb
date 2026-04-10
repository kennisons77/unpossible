# frozen_string_literal: true

# Auto-import snapshots on fresh databases.
# Runs after migrations, before the app serves requests.
Rails.application.config.after_initialize do
  # Ledger snapshot (git-tracked)
  if Ledger::Node.table_exists? && !Ledger::Node.exists?
    snapshot = Rails.root.join("../ledger/snapshot.yml")
    Ledger::LedgerSnapshotService.import(path: snapshot.to_s) if File.exist?(snapshot)
  end

  # Bulk snapshot (local-only, not in git)
  if Agents::AgentRun.table_exists? && !Agents::AgentRun.exists?
    Agents::BulkSnapshotService.import if File.exist?(File.join(Agents::BulkSnapshotService::SNAPSHOT_DIR, "meta.json"))
  end
end
