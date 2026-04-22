# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarkdownHelper, type: :helper, spec: "specifications/system/infrastructure/concept.md#markdown-helper" do
  describe "#render_markdown" do
    it "returns empty string for blank input" do
      expect(helper.render_markdown(nil)).to eq("")
      expect(helper.render_markdown("")).to eq("")
    end

    it "renders markdown to HTML" do
      result = helper.render_markdown("**bold** and *italic*")
      expect(result).to include("<strong>bold</strong>")
      expect(result).to include("<em>italic</em>")
    end

    it "renders fenced code blocks with syntax highlighting" do
      md = "```ruby\nputs 'hello'\n```"
      result = helper.render_markdown(md)
      expect(result).to include('class="highlight language-ruby"')
      expect(result).to include("<span") # Rouge produces span-wrapped tokens
    end

    it "renders tables" do
      md = "| A | B |\n|---|---|\n| 1 | 2 |"
      result = helper.render_markdown(md)
      expect(result).to include("<table>")
    end

    it "escapes dangerous HTML" do
      result = helper.render_markdown("<script>alert('xss')</script>")
      expect(result).not_to include("<script>")
      expect(result).to include("&lt;script&gt;")
    end

    it "returns html_safe string" do
      expect(helper.render_markdown("hello")).to be_html_safe
    end
  end
end
