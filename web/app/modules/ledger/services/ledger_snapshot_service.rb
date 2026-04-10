# frozen_string_literal: true

module Ledger
  class LedgerSnapshotService
    SNAPSHOT_PATH = Rails.root.join("../ledger/snapshot.yml").to_s

    TABLES = {
      nodes:        Ledger::Node,
      node_edges:   Ledger::NodeEdge,
      audit_events: Ledger::NodeAuditEvent
    }.freeze

    def self.export(path: SNAPSHOT_PATH)
      FileUtils.mkdir_p(File.dirname(path))

      data = TABLES.transform_values { |klass| klass.all.map(&:attributes) }
      data[:exported_at] = Time.current.iso8601

      File.write(path, data.deep_stringify_keys.to_yaml)
      Rails.logger.info("[LedgerSnapshot] exported #{data[:nodes].size} nodes to #{path}")
      path
    end

    def self.import(path: SNAPSHOT_PATH)
      return unless File.exist?(path)
      return if Ledger::Node.exists? # don't clobber existing data

      data = YAML.safe_load_file(path, permitted_classes: [Time, Date, ActiveSupport::TimeWithZone])

      ActiveRecord::Base.transaction do
        (data["nodes"] || []).each { |attrs| Ledger::Node.insert!(attrs) }
        (data["node_edges"] || []).each { |attrs| Ledger::NodeEdge.insert!(attrs) }
        (data["audit_events"] || []).each { |attrs| Ledger::NodeAuditEvent.insert!(attrs) }
      end

      count = data["nodes"]&.size || 0
      Rails.logger.info("[LedgerSnapshot] imported #{count} nodes from #{path}")
      count
    end
  end
end
