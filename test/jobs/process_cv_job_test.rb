require "test_helper"

# frozen_string_literal: true

class ProcessCvJobTest < ActiveSupport::TestCase
  def setup
    @job = jobs(:active_job)
    @candidate = Candidate.create!(
      name:  "Proc Essor",
      email: "proc@example.com",
      job:   @job
    )
  end

  # ── Happy path (text file — no PDF extraction API call) ──────────────────────

  test "extracts text, transitions to ready_for_evaluating, then runs evaluation" do
    attach_text_cv("# Proc Essor\n\n6 years Rails.")
    stub_anthropic_messages(text: evaluation_json)  # for EvaluateCvJob

    ProcessCvJob.perform_now(@candidate.id)

    assert_equal "evaluated", @candidate.reload.current_state
  end

  test "stores the extracted cv_raw_text on the candidate" do
    attach_text_cv("# My CV\n\nRails developer.")
    stub_anthropic_messages(text: evaluation_json)

    ProcessCvJob.perform_now(@candidate.id)

    assert_includes @candidate.reload.cv_raw_text, "My CV"
  end

  # ── PDF path ─────────────────────────────────────────────────────────────────

  test "extracts PDF via Claude and proceeds to evaluation" do
    attach_pdf_cv
    # First stub: PDF extraction; second stub: evaluation.
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        { status: 200, body: anthropic_body("# Extracted CV\n\nSenior Rails."), headers: json_headers },
        { status: 200, body: anthropic_body(evaluation_json), headers: json_headers }
      )

    ProcessCvJob.perform_now(@candidate.id)

    assert_equal "evaluated", @candidate.reload.current_state
  end

  # ── Guard clauses ────────────────────────────────────────────────────────────

  test "is a no-op when no file is attached" do
    assert_nothing_raised { ProcessCvJob.perform_now(@candidate.id) }
    assert_equal "cv_processing", @candidate.reload.current_state
  end

  test "is a no-op when cv_raw_text is already present" do
    @candidate.update!(cv_raw_text: "already extracted")
    attach_text_cv("should not be read again")

    ProcessCvJob.perform_now(@candidate.id)

    assert_equal "already extracted", @candidate.reload.cv_raw_text
    assert_not_requested :post, "https://api.anthropic.com/v1/messages"
  end

  # ── Error propagation ────────────────────────────────────────────────────────

  test "re-raises CvProcessor::Error so the job fails" do
    # Attach a file that is too large to trigger CvProcessor::Error.
    attach_file(content: "x" * (33 * 1024 * 1024), filename: "huge.pdf", content_type: "application/pdf")

    assert_raises CvProcessor::Error do
      ProcessCvJob.perform_now(@candidate.id)
    end
  end

  private

  def attach_text_cv(content)
    attach_file(content: content, filename: "cv.txt", content_type: "text/plain")
  end

  def attach_pdf_cv
    attach_file(
      content:      "%PDF-1.4 minimal pdf",
      filename:     "cv.pdf",
      content_type: "application/pdf"
    )
  end

  def attach_file(content:, filename:, content_type:)
    @candidate.cv_file.attach(
      io:           StringIO.new(content),
      filename:     filename,
      content_type: content_type
    )
  end

  def evaluation_json
    { overall: "pass", score: 85, summary: "Good fit.", gaps: [], questions: [] }.to_json
  end

  def anthropic_body(text)
    {
      id:            "msg_test",
      type:          "message",
      role:          "assistant",
      content:       [ { type: "text", text: text } ],
      model:         "claude-opus-4-6",
      stop_reason:   "end_turn",
      stop_sequence: nil,
      usage:         { input_tokens: 100, output_tokens: 50 }
    }.to_json
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
