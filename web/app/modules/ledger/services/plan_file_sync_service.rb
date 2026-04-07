# frozen_string_literal: true

module Ledger
  class PlanFileSyncService
    CHECKBOX_RE = /^\s*-\s*\[(?<checked>[xX ])\]\s+(?<body>.+?)(?:\s*<!--\s*ref:\s*(?<ref>[^\s>]+)\s*-->)?$/

    def self.sync(plan_path:, org_id:)
      new(plan_path: plan_path, org_id: org_id).sync
    end

    def initialize(plan_path:, org_id:)
      @plan_path = plan_path
      @org_id    = org_id
    end

    def sync
      lines = File.readlines(@plan_path, chomp: true)
      seen_refs = []

      lines.each do |line|
        m = CHECKBOX_RE.match(line)
        next unless m
        next unless m[:ref]

        stable_ref = m[:ref]
        checked    = m[:checked].strip.downcase == "x"
        body       = m[:body].gsub(/<!--.*?-->/, "").strip
        seen_refs << stable_ref

        node = Node.find_by(stable_ref: stable_ref, org_id: @org_id)

        if node.nil?
          Node.create!(
            kind:        "question",
            scope:       "code",
            author:      "system",
            body:        body,
            stable_ref:  stable_ref,
            org_id:      @org_id,
            recorded_at: Time.current,
            status:      checked ? "closed" : "proposed"
          )
        elsif checked && node.status != "closed"
          node.update!(status: "closed", version: (node.version || 1) + 1)
        elsif !checked && node.status == "closed"
          node.update!(status: "proposed", version: (node.version || 1) + 1)
        end
      end

      # Flag orphans — nodes with scope:code/author:system whose stable_ref no longer appears.
      # NOTE: `scope` is a reserved AR method name; use raw SQL for that column.
      # NOTE: resolution IS NULL must be included — SQL `!= 'deferred'` excludes NULLs.
      orphans = Node
        .where(org_id: @org_id, author: "system")
        .where("ledger_nodes.scope = ?", "code")
        .where("ledger_nodes.resolution IS NULL OR ledger_nodes.resolution != ?", "deferred")
      orphans = orphans.where.not(stable_ref: seen_refs) if seen_refs.any?
      orphans.update_all(resolution: "deferred")
    end
  end
end
