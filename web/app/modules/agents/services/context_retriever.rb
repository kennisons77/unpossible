# frozen_string_literal: true

module Agents
  # Loads practices files declared in a skill's frontmatter `principles` list.
  # Returns an array of content strings (context chunks) for prompt assembly.
  #
  # Principle names map to files in specifications/practices/.
  # Missing files are skipped silently (fail open — context loading is a pipeline
  # invisible step, not a core workflow step).
  class ContextRetriever
    PRACTICES_DIR = "specifications/practices"

    # Returns an array of file content strings for the given principle names.
    # principles — array of short names, e.g. ["cost", "coding", "verification"]
    def self.call(principles)
      Array(principles).filter_map do |name|
        path = resolve_path(name)
        next unless File.exist?(path)

        File.read(path)
      rescue Errno::EACCES, Errno::EISDIR
        nil
      end
    end

    def self.resolve_path(name)
      Rails.root.join("..", PRACTICES_DIR, "#{name}.md").to_s
    end
    private_class_method :resolve_path
  end
end
