# frozen_string_literal: true

namespace :ledger do
  desc "Export ledger state to ledger/snapshot.yml"
  task export: :environment do
    path = Ledger::LedgerSnapshotService.export
    puts "Exported to #{path}"
  end

  desc "Import ledger state from ledger/snapshot.yml (skips if DB already has data)"
  task import: :environment do
    count = Ledger::LedgerSnapshotService.import
    if count
      puts "Imported #{count} nodes"
    else
      puts "Skipped — DB already has ledger data or snapshot missing"
    end
  end

  desc "Seed ledger from specs and implementation plan (runs SpecWatcherJob synchronously)"
  task seed: :environment do
    if Ledger::Node.exists?
      puts "Skipped — ledger already has data"
    else
      Ledger::SpecWatcherJob.perform_now
      puts "Seeded #{Ledger::Node.count} nodes from specs"
    end
  end
end

namespace :bulk do
  desc "Export agent runs, knowledge, and actor data to .data/snapshots/ (not git-tracked)"
  task export: :environment do
    dir = Agents::BulkSnapshotService.export
    puts "Exported to #{dir}"
  end

  desc "Import agent runs, knowledge, and actor data from .data/snapshots/"
  task import: :environment do
    Agents::BulkSnapshotService.import
    puts "Import complete"
  end
end
