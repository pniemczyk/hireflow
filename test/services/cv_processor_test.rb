require "test_helper"

# frozen_string_literal: true

class CvProcessorTest < ActiveSupport::TestCase
  def setup
    @job       = jobs(:active_job)
    @candidate = Candidate.create!(name: "Test", email: "proc@example.com", job: @job)
  end

  # ── Plain text / Markdown ────────────────────────────────────────────────────

  test "reads a plain text file without calling the API" do
    attach_file(content: "# Jane Doe\n\nRails developer.", filename: "cv.txt", content_type: "text/plain")

    result = CvProcessor.new(@candidate).call

    assert_includes result, "Jane Doe"
    assert_not_requested :post, "https://api.anthropic.com/v1/messages"
  end

  test "reads a markdown file without calling the API" do
    attach_file(content: "## Skills\n\n- Ruby", filename: "cv.md", content_type: "text/markdown")

    result = CvProcessor.new(@candidate).call

    assert_includes result, "Skills"
    assert_not_requested :post, "https://api.anthropic.com/v1/messages"
  end

  # ── PDF extraction via Claude ─────────────────────────────────────────────────

  test "sends PDF to Claude and returns extracted Markdown" do
    attach_file(content: pdf_bytes, filename: "cv.pdf", content_type: "application/pdf")
    stub_anthropic_messages(text: "# Extracted CV\n\nSenior Rails developer.")

    result = CvProcessor.new(@candidate).call

    assert_includes result, "Extracted CV"
  end

  test "raises Error when PDF exceeds 32 MB" do
    large_bytes = "x" * (33 * 1024 * 1024)
    attach_file(content: large_bytes, filename: "huge.pdf", content_type: "application/pdf")

    assert_raises CvProcessor::Error, /too large/ do
      CvProcessor.new(@candidate).call
    end
  end

  # ── Guard clauses ────────────────────────────────────────────────────────────

  test "raises Error when no file is attached" do
    assert_raises CvProcessor::Error, /No attached file/ do
      CvProcessor.new(@candidate).call
    end
  end

  private

  def attach_file(content:, filename:, content_type:)
    @candidate.cv_file.attach(
      io:           StringIO.new(content),
      filename:     filename,
      content_type: content_type
    )
  end

  # Minimal valid-ish PDF header so content_type detection doesn't change it.
  def pdf_bytes
    "%PDF-1.4 1 0 obj << /Type /Catalog >> endobj"
  end
end
