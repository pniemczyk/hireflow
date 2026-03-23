require 'test_helper'

# frozen_string_literal: true

class CandidateTest < ActiveSupport::TestCase
  def setup
    @job = jobs(:active_job)
    @candidate = Candidate.new(name: 'Jane Doe', email: 'jane@example.com', job: @job)
  end

  # ── State machine ────────────────────────────────────────────────────────────

  test 'initial current_state is cv_processing' do
    @candidate.save!
    assert_equal 'cv_processing', @candidate.current_state
  end

  test 'transitions from cv_processing to ready_for_evaluating' do
    @candidate.save!
    @candidate.transition_to!(:ready_for_evaluating)
    assert_equal 'ready_for_evaluating', @candidate.current_state
  end

  test 'cannot transition from cv_processing directly to evaluating' do
    @candidate.save!
    assert_raises Statesman::TransitionFailedError do
      @candidate.transition_to!(:evaluating)
    end
  end

  test 'STATUSES includes all defined states' do
    %w[cv_processing ready_for_evaluating evaluating evaluated
       interviewing completed accepted rejected].each do |state|
      assert_includes Candidate::STATUSES, state
    end
  end

  # ── Status column sync ───────────────────────────────────────────────────────

  test 'status column stays in sync after transition' do
    @candidate.save!
    @candidate.transition_to!(:ready_for_evaluating)
    assert_equal 'ready_for_evaluating', @candidate.reload.status
  end

  # ── inquiry_attrs predicates ─────────────────────────────────────────────────

  test 'status.cv_processing? is true for a new candidate' do
    @candidate.save!
    assert @candidate.status.cv_processing?
  end

  test 'status.evaluating? is false for a new candidate' do
    @candidate.save!
    refute @candidate.status.evaluating?
  end

  test 'status predicate is nil-safe when status is nil' do
    @candidate.status = nil
    assert @candidate.status.nil?
    refute @candidate.status.cv_processing?
  end

  # ── cv_provided? ─────────────────────────────────────────────────────────────

  test '#cv_provided? returns false with no file or text' do
    refute @candidate.cv_provided?
  end

  test '#cv_provided? returns true when cv_raw_text is present' do
    @candidate.cv_raw_text = '# My CV'
    assert @candidate.cv_provided?
  end

  test '#cv_provided? returns true when a file is attached' do
    @candidate.cv_file.attach(
      io:           StringIO.new('cv content'),
      filename:     'cv.txt',
      content_type: 'text/plain'
    )
    assert @candidate.cv_provided?
  end

  # ── evaluation ───────────────────────────────────────────────────────────────

  test '#evaluation returns nil when evaluation_result is blank' do
    assert_nil @candidate.evaluation
  end

  test '#evaluation parses JSON into a symbolized hash' do
    @candidate.evaluation_result = '{"overall":"pass","score":85,"summary":"Good.","gaps":[],"questions":[]}'
    result = @candidate.evaluation
    assert_equal 'pass', result[:overall]
    assert_equal 85,     result[:score]
  end

  test '#evaluation returns nil on malformed JSON' do
    @candidate.evaluation_result = 'not-json'
    assert_nil @candidate.evaluation
  end

  # ── Validations ──────────────────────────────────────────────────────────────

  test 'is invalid without a job' do
    @candidate.job = nil
    refute @candidate.valid?
    assert_includes @candidate.errors[:job], 'must exist'
  end
end
