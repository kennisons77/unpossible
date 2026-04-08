# frozen_string_literal: true

module MarkdownHelper
  RENDERER = Redcarpet::Render::HTML.new(
    hard_wrap: true,
    escape_html: true,
    link_attributes: { target: "_blank", rel: "noopener noreferrer" }
  )

  MARKDOWN = Redcarpet::Markdown.new(
    RENDERER,
    fenced_code_blocks: true,
    autolink: true,
    tables: true,
    strikethrough: true
  )

  def render_markdown(text)
    return "" if text.blank?

    html = MARKDOWN.render(text)
    # Apply Rouge syntax highlighting to fenced code blocks
    html = html.gsub(/<code class="(\w+)">(.*?)<\/code>/m) do
      lang, code = Regexp.last_match(1), CGI.unescapeHTML(Regexp.last_match(2))
      lexer = Rouge::Lexer.find(lang) || Rouge::Lexers::PlainText
      formatter = Rouge::Formatters::HTML.new
      "<code class=\"highlight language-#{lang}\">#{formatter.format(lexer.lex(code))}</code>"
    end
    html.html_safe
  end
end
