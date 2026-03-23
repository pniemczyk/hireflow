# frozen_string_literal: true

require 'test_helper'

class ConversationTest < ActiveSupport::TestCase
  def setup
    # Use fresh_candidate — no conversation fixture attached to it.
    @candidate    = candidates(:fresh_candidate)
    @conversation = Conversation.new(candidate: @candidate)
  end

  # ── Associations ─────────────────────────────────────────────────────────────

  test 'belongs_to candidate' do
    @conversation.save!
    assert_equal @candidate, @conversation.candidate
  end

  test 'has many messages ordered by position' do
    @conversation.save!
    m2 = @conversation.messages.create!(role: 'ai',        content: 'Second', position: 2)
    m1 = @conversation.messages.create!(role: 'candidate', content: 'First',  position: 1)
    assert_equal [m1, m2], @conversation.messages.to_a
  end

  test 'destroying conversation destroys messages' do
    @conversation.save!
    @conversation.messages.create!(role: 'ai', content: 'Hi', position: 1)
    assert_difference 'Message.count', -1 do
      @conversation.destroy
    end
  end

  # ── Validations ──────────────────────────────────────────────────────────────

  test 'is valid with default state' do
    assert @conversation.valid?
  end

  test 'is invalid with unrecognised state' do
    @conversation.state = 'limbo'
    refute @conversation.valid?
    assert_includes @conversation.errors[:state], 'is not included in the list'
  end

  test 'is invalid without a candidate' do
    @conversation.candidate = nil
    refute @conversation.valid?
  end

  # ── Default values ───────────────────────────────────────────────────────────

  test 'defaults to in_progress state' do
    @conversation.save!
    assert_equal 'in_progress', @conversation.state
  end

  test 'started_at defaults to current time on create' do
    @conversation.save!
    assert_in_delta Time.current.to_i, @conversation.started_at.to_i, 5
  end

  # ── Lifecycle helpers ────────────────────────────────────────────────────────

  test '#complete! sets state to completed and stamps completed_at' do
    @conversation.save!
    @conversation.complete!
    assert_equal 'completed', @conversation.reload.state
    assert_in_delta Time.current.to_i, @conversation.completed_at.to_i, 5
  end

  test '#fail! sets state to failed and stamps completed_at' do
    @conversation.save!
    @conversation.fail!
    assert_equal 'failed', @conversation.reload.state
    assert_in_delta Time.current.to_i, @conversation.completed_at.to_i, 5
  end
end
