require 'test_helper'

# frozen_string_literal: true

class JobTest < ActiveSupport::TestCase
  # ── Scopes ───────────────────────────────────────────────────────────────────

  test '.active returns only active jobs' do
    assert_includes Job.active, jobs(:active_job)
    refute_includes Job.active, jobs(:closed_job)
  end

  test '.closed returns only closed jobs' do
    assert_includes Job.closed, jobs(:closed_job)
    refute_includes Job.closed, jobs(:active_job)
  end

  # ── inquiry_attrs predicates ─────────────────────────────────────────────────

  test 'status.active? is true for an active job' do
    assert jobs(:active_job).status.active?
  end

  test 'status.closed? is true for a closed job' do
    assert jobs(:closed_job).status.closed?
  end

  test 'status.active? is false for a closed job' do
    refute jobs(:closed_job).status.active?
  end

  # ── Validations ──────────────────────────────────────────────────────────────

  test 'is invalid without a title' do
    job = Job.new(status: 'active')
    refute job.valid?
    assert_includes job.errors[:title], "can't be blank"
  end

  test 'is invalid with an unknown status' do
    job = Job.new(title: 'Dev Role', status: 'pending')
    refute job.valid?
    assert_includes job.errors[:status], 'is not included in the list'
  end

  test 'is valid with active status' do
    job = Job.new(title: 'Dev Role', status: 'active')
    assert job.valid?
  end
end
