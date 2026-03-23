# frozen_string_literal: true

require "test_helper"

class InterviewConductorTest < ActiveSupport::TestCase
  def setup
    @candidate = Candidate.create!(
      name:              "Test Candidate",
      email:             "interview@example.com",
      job:               jobs(:active_job),
      cv_raw_text:       '# Test\n\n4 years Rails.',
      evaluation_result: partial_evaluation_json
    )
  end

  # ── Guard clauses ────────────────────────────────────────────────────────────

  test "raises Error when candidate has no evaluation result" do
    @candidate.evaluation_result = nil
    assert_raises InterviewConductor::Error, /No evaluation result/ do
      InterviewConductor.new(@candidate).call
    end
  end

  test "raises Error when job has no scenario" do
    jobs(:active_job).scenario.destroy!
    assert_raises InterviewConductor::Error, /no scenario/ do
      InterviewConductor.new(@candidate.reload).call
    end
  end

  # ── Happy path — opening ─────────────────────────────────────────────────────

  test "returns a structured hash with required keys when no conversation exists" do
    stub_anthropic_messages(text: valid_opening_json)

    result = InterviewConductor.new(@candidate).call

    assert_equal "Welcome! Tell me about your background job experience.", result[:content]
    assert_equal false, result[:complete]
    assert_equal 0,     result[:question_index]
    assert_equal 1,     result[:attempt]
    assert_nil          result[:summary]
  end

  test "complete is false when interview is ongoing" do
    stub_anthropic_messages(text: valid_opening_json)
    result = InterviewConductor.new(@candidate).call
    assert_equal false, result[:complete]
  end

  # ── Happy path — mid-interview ───────────────────────────────────────────────

  test "includes conversation history when messages exist" do
    conv = Conversation.create!(candidate: @candidate)
    conv.messages.create!(role: "ai",        content: "Tell me about Sidekiq.")
    conv.messages.create!(role: "candidate", content: "I used it for email jobs.")

    stub_anthropic_messages(text: valid_followup_json)
    result = InterviewConductor.new(@candidate.reload).call

    assert_equal false, result[:complete]
    assert_equal 0,     result[:question_index]
    assert_equal 2,     result[:attempt]
  end

  # ── Happy path — completion ───────────────────────────────────────────────────

  test "returns complete true with a summary hash when interview finishes" do
    stub_anthropic_messages(text: valid_completion_json)

    result = InterviewConductor.new(@candidate).call

    assert_equal true,   result[:complete]
    assert_not_nil       result[:summary]
    assert_equal "pass", result[:summary][:overall]
    assert_equal 78,     result[:summary][:score]
    assert_kind_of Array, result[:summary][:answers]
    assert result[:summary][:summary].present?
  end

  test "returns complete true with fail overall when failure threshold reached" do
    stub_anthropic_messages(text: valid_fail_completion_json)

    result = InterviewConductor.new(@candidate).call

    assert_equal true,   result[:complete]
    assert_equal "fail", result[:summary][:overall]
  end

  # ── Response parsing ──────────────────────────────────────────────────────────

  test "raises Error when API returns invalid JSON" do
    stub_anthropic_messages(text: "not json at all")
    assert_raises InterviewConductor::Error, /Could not parse/ do
      InterviewConductor.new(@candidate).call
    end
  end

  test "raises Error when JSON is missing required keys" do
    stub_anthropic_messages(text: '{"content":"hello","complete":false}')
    assert_raises InterviewConductor::Error, /missing keys/ do
      InterviewConductor.new(@candidate).call
    end
  end

  test "raises Error when complete is true but summary is missing required keys" do
    bad_completion = { content: "Done", complete: true, question_index: 0, attempt: 1,
                       summary: { overall: "pass" } }.to_json
    stub_anthropic_messages(text: bad_completion)
    assert_raises InterviewConductor::Error, /summary missing keys/ do
      InterviewConductor.new(@candidate).call
    end
  end

  test "raises Error when summary overall is not a valid value" do
    bad_summary = valid_completion_hash.deep_merge(summary: { overall: "maybe" })
    stub_anthropic_messages(text: bad_summary.to_json)
    assert_raises InterviewConductor::Error, /Invalid summary overall/ do
      InterviewConductor.new(@candidate).call
    end
  end

  test "strips markdown fences from response before parsing" do
    fenced = "```json\n#{valid_opening_json}\n```"
    stub_anthropic_messages(text: fenced)
    result = InterviewConductor.new(@candidate).call
    assert_equal false, result[:complete]
  end

  # ── API error propagation ─────────────────────────────────────────────────────

  test "bubbles up RateLimitError for retry handling" do
    stub_anthropic_error(status: 429, type: "rate_limit_error", message: "Rate limit exceeded")
    assert_raises Anthropic::Errors::RateLimitError do
      InterviewConductor.new(@candidate).call
    end
  end

  test "bubbles up InternalServerError for retry handling" do
    stub_anthropic_error(status: 500, type: "api_error", message: "Internal server error")
    assert_raises Anthropic::Errors::InternalServerError do
      InterviewConductor.new(@candidate).call
    end
  end

  private

  def partial_evaluation_json
    {
      overall:   "partial",
      score:     60,
      summary:   "Decent fit, some gaps.",
      gaps:      [ "No background job experience mentioned" ],
      questions: [ "Describe your experience with background job processing." ]
    }.to_json
  end

  def valid_opening_json
    {
      content:        "Welcome! Tell me about your background job experience.",
      complete:       false,
      question_index: 0,
      attempt:        1,
      summary:        nil
    }.to_json
  end

  def valid_followup_json
    {
      content:        "Can you give a more specific example of how you used it in production?",
      complete:       false,
      question_index: 0,
      attempt:        2,
      summary:        nil
    }.to_json
  end

  def valid_completion_hash
    {
      content:        "Thank you for your time. We will be in touch.",
      complete:       true,
      question_index: 0,
      attempt:        1,
      summary:        {
        overall:  "pass",
        score:    78,
        answers:  [
          { question: "Describe your background job experience.",
            answer:   "I used Sidekiq for email and report jobs.",
            verdict:  "sufficient" }
        ],
        summary:  "Candidate demonstrated solid background job knowledge."
      }
    }
  end

  def valid_completion_json
    valid_completion_hash.to_json
  end

  def valid_fail_completion_json
    valid_completion_hash.deep_merge(summary: { overall: "fail", score: 20 }).to_json
  end
end
