# frozen_string_literal: true

require "test_helper"

# Tests for status auto-routing behaviour when a candidate reaches `evaluated`.
# The status endpoint should inspect the evaluation result and immediately
# transition the candidate to the appropriate next state, returning a
# `redirect_url` the poller can follow.
class ApplicationsStatusRoutingTest < ActionDispatch::IntegrationTest
  def setup
    @job = jobs(:active_job)
  end

  # ── fail → rejected ──────────────────────────────────────────────────────────

  test "status auto-transitions fail candidate to rejected and returns redirect_url" do
    candidate = create_evaluated_candidate(overall: "fail", questions: [])

    get candidate_application_status_path(@job, candidate_id: candidate.id),
        headers: { Accept: "application/json" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "rejected", body["status"]
    assert_equal job_application_result_path(@job, candidate_id: candidate.id), body["redirect_url"]
    assert_equal "rejected", candidate.reload.current_state
  end

  # ── pass + no questions → accepted ───────────────────────────────────────────

  test "status auto-transitions clean-pass candidate to accepted and returns redirect_url" do
    candidate = create_evaluated_candidate(overall: "pass", questions: [])

    get candidate_application_status_path(@job, candidate_id: candidate.id),
        headers: { Accept: "application/json" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "accepted", body["status"]
    assert_equal job_application_result_path(@job, candidate_id: candidate.id), body["redirect_url"]
    assert_equal "accepted", candidate.reload.current_state
  end

  # ── partial → interviewing ────────────────────────────────────────────────────

  test "status auto-transitions partial candidate to interviewing and returns redirect_url" do
    candidate = create_evaluated_candidate(
      overall: "partial",
      questions: [ "Describe your Sidekiq experience." ]
    )

    get candidate_application_status_path(@job, candidate_id: candidate.id),
        headers: { Accept: "application/json" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "interviewing", body["status"]
    assert_equal job_application_interview_path(@job, candidate_id: candidate.id), body["redirect_url"]
    assert_equal "interviewing", candidate.reload.current_state
  end

  # ── pass + questions → interviewing ──────────────────────────────────────────

  test "status auto-transitions pass-with-questions candidate to interviewing" do
    candidate = create_evaluated_candidate(
      overall: "pass",
      questions: [ "Tell me more about your scaling work." ]
    )

    get candidate_application_status_path(@job, candidate_id: candidate.id),
        headers: { Accept: "application/json" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "interviewing", body["status"]
    assert body["redirect_url"].present?
    assert_equal "interviewing", candidate.reload.current_state
  end

  # ── idempotency: already-transitioned states are not re-triggered ────────────

  test "status returns current state without re-transitioning when already interviewing" do
    candidate = create_evaluated_candidate(
      overall: "partial",
      questions: [ "Tell me about Sidekiq." ]
    )
    # Transition from evaluated → interviewing before the request
    candidate.transition_to!(:interviewing)

    get candidate_application_status_path(@job, candidate_id: candidate.id),
        headers: { Accept: "application/json" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "interviewing", body["status"]
    # Should NOT have a redirect_url — candidate is already past the evaluated gate
    assert_nil body["redirect_url"]
  end

  private

  def create_evaluated_candidate(overall:, questions:)
    candidate = Candidate.create!(
      name:              "Auto Route Candidate",
      email:             "autoroute+#{SecureRandom.hex(4)}@example.com",
      job:               @job,
      cv_raw_text:       "# Test CV",
      evaluation_result: {
        overall:   overall,
        score:     70,
        summary:   "Test summary.",
        gaps:      [],
        questions: questions
      }.to_json
    )
    # Walk the state machine to `evaluated` so Statesman transitions are recorded.
    candidate.transition_to!(:ready_for_evaluating)
    candidate.transition_to!(:evaluating)
    candidate.transition_to!(:evaluated)
    candidate
  end
end
