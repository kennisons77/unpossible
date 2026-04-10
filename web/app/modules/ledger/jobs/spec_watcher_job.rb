# frozen_string_literal: true

module Ledger
  # Polls specs/**/*.md every 10 seconds and syncs Ledger::Node records.
  #
  # Rules:
  #   new file      → create Node (scope: intent, status: open)
  #   changed file  → parse <!-- status: X --> header, apply via NodeLifecycleService
  #   deleted file  → set resolution: deferred
  #   git revert    → set conflict: true, never auto-resolve
  #   any change    → enqueue Knowledge::IndexerJob
  #
  # stable_ref = "spec:<SHA256(rel_path)>" — deterministic, path-based.
  class SpecWatcherJob < ApplicationJob
    queue_as :default

    POLL_INTERVAL = 10 # seconds
    SPECS_GLOB    = "specs/**/*.md"
    STATUS_HEADER = /<!--\s*status:\s*(\w+)\s*-->/i

    def perform(specs_root: nil)
      root = specs_root || Rails.root.parent.to_s
      changed = process_specs(root)
      changed.each { |node| Knowledge::IndexerJob.perform_later(node.id.to_s) if defined?(Knowledge::IndexerJob) }
      sync_plan(root)
      reenqueue(specs_root)
    end

    private

    def reenqueue(specs_root)
      self.class.set(wait: POLL_INTERVAL.seconds).perform_later(specs_root: specs_root)
    end

    def process_specs(root)
      prefix = root == "/" ? "/" : "#{root}/"
      disk_paths = Dir.glob(File.join(root, SPECS_GLOB)).map do |abs|
        abs.delete_prefix(prefix)
      end

      changed_nodes = []

      # Handle new and changed files
      disk_paths.each do |rel_path|
        abs_path = File.join(root, rel_path)
        ref      = stable_ref_for(rel_path)
        node     = Ledger::Node.find_by(stable_ref: ref)

        if node.nil?
          created = create_node_for(rel_path, ref, abs_path)
          changed_nodes << created if created
        else
          changed_nodes << node if sync_node(node, abs_path, root, rel_path)
        end
      end

      build_edges

      # Handle deleted files — find spec-tracked nodes whose file no longer exists on disk
      tracked_paths = disk_paths.to_set
      spec_nodes    = Ledger::Node.where.not(spec_path: nil)
                                  .where("resolution IS NULL OR resolution != ?", "deferred")
      spec_nodes.each do |node|
        next if tracked_paths.include?(node.spec_path)

        node.update!(resolution: "deferred")
        changed_nodes << node
      end

      changed_nodes
    end

    def create_node_for(rel_path, ref, abs_path)
      content = File.read(abs_path)
      Ledger::Node.create!(
        kind:        "question",
        scope:       "intent",
        status:      "proposed",
        author:      "system",
        body:        summary_for(content, rel_path),
        title:       title_for(content, rel_path),
        spec_path:   rel_path,
        stable_ref:  ref,
        org_id:      default_org_id,
        recorded_at: Time.current
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[SpecWatcherJob] failed to create node for #{rel_path}: #{e.message}")
      nil
    end

    # Returns true if the node was modified.
    def sync_node(node, abs_path, root, rel_path)
      return handle_deleted(node) unless File.exist?(abs_path)

      content = File.read(abs_path)

      if git_revert?(root, rel_path, content)
        return false if node.conflict?

        node.update!(conflict: true)
        return true
      end

      new_status = parse_status(content)
      return false if new_status.nil? || new_status == node.status

      begin
        Ledger::NodeLifecycleService.transition(node, new_status)
        true
      rescue Ledger::NodeLifecycleService::LifecycleError => e
        Rails.logger.warn("[SpecWatcherJob] lifecycle error for #{rel_path}: #{e.message}")
        false
      end
    end

    def handle_deleted(node)
      return false if node.resolution == "deferred"

      node.update!(resolution: "deferred")
      true
    end

    # Detect git revert: disk content matches HEAD~1 but not HEAD.
    def git_revert?(root, rel_path, disk_content)
      head_content = git_show(root, "HEAD", rel_path)
      return false if head_content.nil? || head_content == disk_content

      prev_content = git_show(root, "HEAD~1", rel_path)
      prev_content == disk_content
    rescue StandardError
      false
    end

    def git_show(root, ref, rel_path)
      output = `git -C #{Shellwords.escape(root)} show #{ref}:#{Shellwords.escape(rel_path)} 2>/dev/null`
      $CHILD_STATUS.success? ? output : nil
    end

    def parse_status(content)
      match = content.match(STATUS_HEADER)
      return nil unless match

      candidate = match[1].downcase
      Ledger::Node::STATUSES.include?(candidate) ? candidate : nil
    end

    def stable_ref_for(rel_path)
      "spec:#{Digest::SHA256.hexdigest(rel_path)}"
    end

    def title_for(content, rel_path)
      # Extract first markdown heading, fall back to directory-qualified filename
      heading = content.lines.find { |l| l.match?(/\A#\s+/) }
      return heading.sub(/\A#+\s+/, "").strip if heading.present?

      parts = rel_path.split("/")
      name = File.basename(rel_path, ".md").tr("-_", " ").capitalize
      return name unless name.casecmp("Readme").zero? && parts.length > 1

      parts[-2].tr("-_", " ").capitalize
    end

    def summary_for(content, rel_path)
      lines = content.lines.map(&:strip).reject(&:empty?)
      # Skip the heading (already in title), take first paragraph
      lines.shift if lines.first&.match?(/\A#+\s/)
      summary = lines.first(5).join("\n")
      summary.presence || rel_path
    end

    def build_edges
      Ledger::Node.where.not(spec_path: nil).find_each do |node|
        parent_dir = File.dirname(node.spec_path)
        seen = Set.new
        loop do
          break if parent_dir == "." || !seen.add?(parent_dir)

          parent_ref = "spec:#{Digest::SHA256.hexdigest("#{parent_dir}/README.md")}"
          parent_node = Ledger::Node.find_by(stable_ref: parent_ref)

          if parent_node && parent_node.id != node.id
            Ledger::NodeEdge.find_or_create_by!(
              parent: parent_node, child: node, edge_type: "contains"
            )
            break
          end

          parent_dir = File.dirname(parent_dir)
        end
      end
    end

    def default_org_id
      ENV.fetch("DEFAULT_ORG_ID", "00000000-0000-0000-0000-000000000000")
    end

    def sync_plan(root)
      plan_path = File.join(root, "IMPLEMENTATION_PLAN.md")
      return unless File.exist?(plan_path)

      Ledger::PlanFileSyncService.sync(plan_path: plan_path, org_id: default_org_id)
    rescue StandardError => e
      Rails.logger.warn("[SpecWatcherJob] plan sync error: #{e.message}")
    end
  end
end
