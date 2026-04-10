# frozen_string_literal: true

module Agents
  class BulkSnapshotService
    SNAPSHOT_DIR = Rails.root.join("../.data/snapshots").to_s

    TABLES = {
      actor_profiles: Ledger::ActorProfile,
      actors:         Ledger::Actor,
      agent_runs:     Agents::AgentRun,
      agent_run_turns: Agents::AgentRunTurn,
      library_items:  Knowledge::LibraryItem
    }.freeze

    def self.export(dir: SNAPSHOT_DIR)
      FileUtils.mkdir_p(dir)

      TABLES.each do |name, klass|
        path = File.join(dir, "#{name}.jsonl")
        File.open(path, "w") do |f|
          klass.find_each { |record| f.puts(record.attributes.to_json) }
        end
      end

      File.write(File.join(dir, "meta.json"), { exported_at: Time.current.iso8601, tables: TABLES.keys }.to_json)
      Rails.logger.info("[BulkSnapshot] exported to #{dir}")
      dir
    end

    def self.import(dir: SNAPSHOT_DIR)
      meta_path = File.join(dir, "meta.json")
      return unless File.exist?(meta_path)

      # Import in FK order: actor_profiles → actors → agent_runs → turns → library_items
      ActiveRecord::Base.transaction do
        TABLES.each do |name, klass|
          path = File.join(dir, "#{name}.jsonl")
          next unless File.exist?(path)
          next if klass.exists?

          File.foreach(path) { |line| klass.insert!(JSON.parse(line)) }
        end
      end

      Rails.logger.info("[BulkSnapshot] imported from #{dir}")
    end
  end
end
