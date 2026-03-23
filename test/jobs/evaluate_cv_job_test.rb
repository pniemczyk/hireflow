require 'test_helper'

# frozen_string_literal: true

class EvaluateCvJobTest < ActiveSupport::TestCase
  def setup
    @job = jobs(:active_job)
    @candidate = Candidate.create!(
      name:        'Eva Luator',
      email:       'eva@example.com',
      job:         @job,
      cv_raw_text: '# Eva Luator\n\n7 years Rails, TDD, PostgreSQL.'
    )
    # Advance to ready_for_evaluating so the job's guard passes.
    @candidate.transition_to!(:ready_for_evaluating)
  end

  # ── Happy path ───────────────────────────────────────────────────────────────

  test 'transitions candidate through evaluating to evaluated' do
    stub_anthropic_messages(text: evaluation_json)

    EvaluateCvJob.perform_now(@candidate.id)

    assert_equal 'evaluated', @candidate.reload.current_state
  end

  test 'persists the evaluation result JSON' do
    stub_anthropic_messages(text: evaluation_json)

    EvaluateCvJob.perform_now(@candidate.id)

    result = @candidate.reload.evaluation
    assert_equal 'pass', result[:overall]
    assert_equal 90,     result[:score]
  end

  test 'syncs the status column after evaluation' do
    stub_anthropic_messages(text: evaluation_json)

    EvaluateCvJob.perform_now(@candidate.id)

    assert_equal 'evaluated', @candidate.reload.status
  end

  # ── Guard clauses ────────────────────────────────────────────────────────────

  test 'is a no-op when candidate cannot transition to evaluating' do
    # Already at ready_for_evaluating — manually skip ahead past the allowed transition window.
    @candidate.transition_to!(:evaluating)
    @candidate.transition_to!(:evaluated)

    # Should silently return — no error, no state change.
    assert_nothing_raised { EvaluateCvJob.perform_now(@candidate.id) }
    assert_equal 'evaluated', @candidate.reload.current_state
  end

  # ── Error propagation ────────────────────────────────────────────────────────

  test 're-raises CvEvaluator::Error so the job fails' do
    # Cause evaluator to fail: remove the scenario.
    @job.scenario.destroy!

    assert_raises CvEvaluator::Error do
      EvaluateCvJob.perform_now(@candidate.id)
    end
  end

  private

  def evaluation_json
    { overall: 'pass', score: 90, summary: 'Excellent fit.', gaps: [], questions: [] }.to_json
  end
end
