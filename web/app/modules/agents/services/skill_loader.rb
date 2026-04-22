# frozen_string_literal: true

module Agents
  # Loads a skill file from disk, parses its YAML frontmatter, and returns
  # the instruction body plus tool declarations (enrich and callable).
  #
  # Skill files live anywhere on disk — source_ref is an absolute or Rails-root-relative
  # path. Missing files and malformed frontmatter are handled gracefully (fail open).
  class SkillLoader
    Result = Data.define(:body, :enrich_tools, :callable_tools)

    FRONTMATTER_PATTERN = /\A---\n(.*?)\n---\n?(.*)\z/m

    # Returns a Result with body, enrich_tools, callable_tools.
    # Returns an empty Result when the file is missing or unreadable.
    def self.call(source_ref)
      return empty_result if source_ref.blank?

      path = resolve_path(source_ref)
      return empty_result unless File.exist?(path)

      raw = File.read(path)
      parse(raw)
    rescue Errno::EACCES, Errno::EISDIR
      empty_result
    end

    def self.empty_result
      Result.new(body: "", enrich_tools: [], callable_tools: [])
    end

    def self.resolve_path(source_ref)
      # Absolute paths pass through; relative paths are resolved from Rails root.
      Pathname.new(source_ref).absolute? ? source_ref : Rails.root.join("..", source_ref).to_s
    end

    def self.parse(raw)
      match = FRONTMATTER_PATTERN.match(raw)
      unless match
        # No frontmatter — entire file is the body
        return Result.new(body: raw.strip, enrich_tools: [], callable_tools: [])
      end

      frontmatter = YAML.safe_load(match[1]) || {}
      body = match[2].strip

      tools = frontmatter["tools"] || {}
      enrich = Array(tools.is_a?(Hash) ? tools["enrich"] : nil)
      callable = Array(tools.is_a?(Hash) ? tools["callable"] : nil)

      Result.new(body: body, enrich_tools: enrich, callable_tools: callable)
    rescue Psych::Exception
      # Malformed YAML frontmatter — return body-only with empty tools
      Result.new(body: raw.strip, enrich_tools: [], callable_tools: [])
    end

    private_class_method :empty_result, :resolve_path, :parse
  end
end
