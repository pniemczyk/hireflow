# frozen_string_literal: true

module ApplicationHelper
  MARKDOWN_RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true),
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    no_intra_emphasis: true
  )

  def markdown(text)
    return "" if text.blank?
    raw MARKDOWN_RENDERER.render(text)
  end
end
