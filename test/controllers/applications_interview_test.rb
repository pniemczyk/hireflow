# frozen_string_literal: true

require "test_helper"

class ApplicationsInterviewTest < ActionDispatch::IntegrationTest
  def setup
    @job = jobs(:active_job)
  end

  # ── GET interview — guard ─────────────────────────────────────────────────────

  test "GET interview redirects to status page when candidate is not interviewing" do
    candidate = create_interviewing_candidate
    # Transition back: only possible via force — instead just use a fresh evaluated candidate.
    other = create_evaluated_candidate

    get job_application_interview_path(@job, candidate_id: other.id)
    assert_redirected_to candidate_application_status_path(@job, candidate_id: other.id)
  end

  # ── GET interview — opening message ──────────────────────────────────────────

  test "GET interview with fresh interviewing candidate creates opening AI message" do
    candidate = create_interviewing_candidate
    stub_anthropic_messages(text: valid_opening_json)

    assert_difference "Message.count", 1 do
      get job_application_interview_path(@job, candidate_id: candidate.id)
    end

    assert_response :ok
    msg = candidate.reload.conversation.messages.first
    assert_equal "ai", msg.role
    assert_equal "Welcome! Tell me about your background job experience.", msg.content
  end

  test "GET interview does not re-generate opening when messages already exist" do
    candidate = create_interviewing_candidate
    conv      = Conversation.create!(candidate: candidate)
    conv.messages.create!(role: "ai", content: "Already here.")

    assert_no_difference "Message.count" do
      get job_application_interview_path(@job, candidate_id: candidate.id)
    end

    assert_response :ok
  end

  # ── POST create_message ───────────────────────────────────────────────────────

  test "POST create_message appends candidate and AI messages" do
    candidate = create_interviewing_candidate_with_conversation

    stub_anthropic_messages(text: valid_followup_json)

    assert_difference "Message.count", 2 do
      post job_application_messages_path(@job, candidate_id: candidate.id),
           params: { content: "I used Sidekiq for background jobs." },
           headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    messages = candidate.reload.conversation.messages.order(:position)
    assert_equal "candidate", messages.second_to_last.role
    assert_equal "I used Sidekiq for background jobs.", messages.second_to_last.content
    assert_equal "ai", messages.last.role
  end

  test "POST create_message responds with Turbo Stream" do
    candidate = create_interviewing_candidate_with_conversation
    stub_anthropic_messages(text: valid_followup_json)

    post job_application_messages_path(@job, candidate_id: candidate.id),
         params: { content: "My answer." },
         headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  test "POST create_message when AI returns complete:true transitions candidate to completed" do
    candidate = create_interviewing_candidate_with_conversation
    stub_anthropic_messages(text: valid_completion_json)

    post job_application_messages_path(@job, candidate_id: candidate.id),
         params: { content: "Final answer." },
         headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_equal "completed", candidate.reload.current_state
    assert candidate.reload.interview_summary.present?
  end

  test "POST create_message when interview summary overall is fail transitions to rejected" do
    candidate = create_interviewing_candidate_with_conversation
    stub_anthropic_messages(text: valid_fail_completion_json)

    post job_application_messages_path(@job, candidate_id: candidate.id),
         params: { content: "Final answer." },
         headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_equal "rejected", candidate.reload.current_state
  end

  test "POST create_message with blank content returns 422" do
    candidate = create_interviewing_candidate_with_conversation

    post job_application_messages_path(@job, candidate_id: candidate.id),
         params: { content: "" },
         headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
  end

  # ── GET result ────────────────────────────────────────────────────────────────

  test "GET result renders result view for a completed candidate" do
    candidate = create_interviewing_candidate
    candidate.transition_to!(:completed)

    get job_application_result_path(@job, candidate_id: candidate.id)
    assert_response :ok
  end

  test "GET result redirects to status page when candidate is not in terminal state" do
    candidate = create_interviewing_candidate

    get job_application_result_path(@job, candidate_id: candidate.id)
    assert_redirected_to candidate_application_status_path(@job, candidate_id: candidate.id)
  end

  private

  RESULT_TERMINAL_STATES = %w[completed accepted rejected].freeze

  def create_evaluated_candidate
    c = Candidate.create!(
      name:              "Eval Candidate",
      email:             "eval+#{SecureRandom.hex(4)}@example.com",
      job:               @job,
      cv_raw_text:       "# Test CV",
      evaluation_result: partial_evaluation_json
    )
    c.transition_to!(:ready_for_evaluating)
    c.transition_to!(:evaluating)
    c.transition_to!(:evaluated)
    c
  end

  def create_interviewing_candidate
    c = create_evaluated_candidate
    c.transition_to!(:interviewing)
    c
  end

  def create_interviewing_candidate_with_conversation
    candidate = create_interviewing_candidate
    conv      = Conversation.create!(candidate: candidate)
    conv.messages.create!(role: "ai", content: "Tell me about Sidekiq.")
    candidate.reload
  end

  def partial_evaluation_json
    {
      overall:   "partial",
      score:     60,
      summary:   "Decent fit.",
      gaps:      [ "No background job experience" ],
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
      content:        "Can you give a more specific example?",
      complete:       false,
      question_index: 0,
      attempt:        2,
      summary:        nil
    }.to_json
  end

  def valid_completion_hash
    {
      content:        "Thank you for your time.",
      complete:       true,
      question_index: 0,
      attempt:        2,
      summary:        {
        overall:  "pass",
        score:    78,
        answers:  [ { question: "Describe background job experience.", answer: "Used Sidekiq.", verdict: "sufficient" } ],
        summary:  "Solid background job knowledge."
      }
    }
  end

  def valid_completion_json   = valid_completion_hash.to_json
  def valid_fail_completion_json = valid_completion_hash.deep_merge(summary: { overall: "fail", score: 20 }).to_json
end
