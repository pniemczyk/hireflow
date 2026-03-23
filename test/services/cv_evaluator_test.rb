require "test_helper"

# frozen_string_literal: true

class CvEvaluatorTest < ActiveSupport::TestCase
  def setup
    @job       = jobs(:active_job)
    @candidate = Candidate.create!(
      name:        "Test Candidate",
      email:       "eval@example.com",
      job:         @job,
      cv_raw_text: '# John Doe\n\n6 years Rails, PostgreSQL, RSpec, Sidekiq.'
    )
  end

  # ── Happy path ───────────────────────────────────────────────────────────────

  test "returns a structured evaluation hash on success" do
    stub_anthropic_messages(text: valid_evaluation_json)

    result = CvEvaluator.new(@candidate).call

    assert_equal "pass",             result[:overall]
    assert_equal 88,                 result[:score]
    assert_equal "Strong candidate", result[:summary]
    assert_equal [],                 result[:gaps]
    assert_equal [],                 result[:questions]
  end

  # ── Guard clauses ────────────────────────────────────────────────────────────

  test "raises Error when cv_raw_text is blank" do
    @candidate.cv_raw_text = nil
    assert_raises CvEvaluator::Error, /No CV text/ do
      CvEvaluator.new(@candidate).call
    end
  end

  test "raises Error when job has no scenario" do
    @job.scenario.destroy!
    assert_raises CvEvaluator::Error, /no evaluation scenario/ do
      CvEvaluator.new(@candidate.reload).call
    end
  end

  # ── Response parsing ─────────────────────────────────────────────────────────

  test "raises Error when API returns invalid JSON" do
    stub_anthropic_messages(text: "not json at all")
    assert_raises CvEvaluator::Error, /Could not parse/ do
      CvEvaluator.new(@candidate).call
    end
  end

  test "raises Error when JSON is missing required keys" do
    stub_anthropic_messages(text: '{"overall":"pass","score":80}')
    assert_raises CvEvaluator::Error, /missing keys/ do
      CvEvaluator.new(@candidate).call
    end
  end

  test "raises Error when overall is not a valid value" do
    stub_anthropic_messages(text: '{"overall":"maybe","score":50,"summary":"ok","gaps":[],"questions":[]}')
    assert_raises CvEvaluator::Error, /Invalid overall/ do
      CvEvaluator.new(@candidate).call
    end
  end

  test "strips markdown fences from response before parsing" do
    fenced = "```json\n#{valid_evaluation_json}\n```"
    stub_anthropic_messages(text: fenced)
    result = CvEvaluator.new(@candidate).call
    assert_equal "pass", result[:overall]
  end

  # ── API error propagation ────────────────────────────────────────────────────

  test "bubbles up RateLimitError for retry handling" do
    stub_anthropic_error(status: 429, type: "rate_limit_error", message: "Rate limit exceeded")
    assert_raises Anthropic::Errors::RateLimitError do
      CvEvaluator.new(@candidate).call
    end
  end

  test "bubbles up InternalServerError for retry handling" do
    stub_anthropic_error(status: 500, type: "api_error", message: "Internal server error")
    assert_raises Anthropic::Errors::InternalServerError do
      CvEvaluator.new(@candidate).call
    end
  end

  private

  def valid_evaluation_json
    { overall: "pass", score: 88, summary: "Strong candidate", gaps: [], questions: [] }.to_json
  end
end
