# frozen_string_literal: true

module Knowledge
  class MdChunker
    HEADING_RE = /\A\#{1,6}\s/

    def self.chunk(text)
      new(text).chunk
    end

    def initialize(text)
      @text = text.to_s
    end

    def chunk
      return [] if @text.strip.empty?

      sections = split_into_sections
      sections.each_with_index.map do |content, index|
        { content: content, chunk_index: index }
      end
    end

    private

    def split_into_sections
      chunks = []
      current = []

      @text.each_line do |line|
        if line.match?(HEADING_RE) && current.any?
          add_chunk(chunks, current)
          current = [line]
        elsif line.strip.empty? && current.any? && !heading_block?(current)
          add_chunk(chunks, current)
          current = []
        else
          current << line
        end
      end

      add_chunk(chunks, current)
      chunks
    end

    def heading_block?(lines)
      lines.length == 1 && lines.first.match?(HEADING_RE)
    end

    def add_chunk(chunks, lines)
      content = lines.join.strip
      chunks << content unless content.empty?
    end
  end
end
