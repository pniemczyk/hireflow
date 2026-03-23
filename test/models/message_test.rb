# frozen_string_literal: true

require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def setup
    # Use text_candidate — no conversation fixture attached to it.
    candidate     = candidates(:text_candidate)
    @conversation = Conversation.create!(candidate: candidate)
  end

  def build_message(attrs = {})
    @conversation.messages.build({ role: "ai", content: "Hello." }.merge(attrs))
  end

  # ── Associations ─────────────────────────────────────────────────────────────

  test "belongs_to conversation" do
    msg = @conversation.messages.create!(role: "ai", content: "Hi")
    assert_equal @conversation, msg.conversation
  end

  # ── Validations ──────────────────────────────────────────────────────────────

  test "is valid with role ai and content" do
    assert build_message(role: "ai").valid?
  end

  test "is valid with role candidate" do
    assert build_message(role: "candidate").valid?
  end

  test "is invalid with unknown role" do
    msg = build_message(role: "recruiter")
    refute msg.valid?
    assert_includes msg.errors[:role], "is not included in the list"
  end

  test "is invalid without content" do
    msg = build_message(content: "")
    refute msg.valid?
    assert_includes msg.errors[:content], "can't be blank"
  end

  # ── Auto position ────────────────────────────────────────────────────────────

  test "position is auto-set to 1 for the first message" do
    msg = @conversation.messages.create!(role: "ai", content: "First")
    assert_equal 1, msg.position
  end

  test "position increments for each subsequent message" do
    @conversation.messages.create!(role: "ai",       content: "First")
    @conversation.messages.create!(role: "candidate", content: "Second")
    third = @conversation.messages.create!(role: "ai", content: "Third")
    assert_equal 3, third.position
  end

  test "position is unique within a conversation" do
    @conversation.messages.create!(role: "ai", content: "First")
    duplicate = @conversation.messages.build(role: "candidate", content: "Dup", position: 1)
    refute duplicate.valid?
    assert_includes duplicate.errors[:position], "has already been taken"
  end

  test "positions are independent across conversations" do
    other_candidate  = candidates(:partial_candidate)
    other_conv       = Conversation.create!(candidate: other_candidate)
    other_conv.messages.create!(role: "ai", content: "Other conv first")

    msg = @conversation.messages.create!(role: "ai", content: "This conv first")
    assert_equal 1, msg.position
  end

  # ── metadata_hash ────────────────────────────────────────────────────────────

  test "#metadata_hash returns empty hash when metadata is blank" do
    msg = @conversation.messages.create!(role: "ai", content: "Hi")
    assert_equal({}, msg.metadata_hash)
  end

  test "#metadata_hash returns symbolized hash from JSON" do
    msg = @conversation.messages.create!(
      role:     "ai",
      content:  "Hi",
      metadata: '{"question_index":2,"attempt":1,"verdict":"sufficient"}'
    )
    assert_equal 2, msg.metadata_hash[:question_index]
    assert_equal 1, msg.metadata_hash[:attempt]
  end

  test "#metadata_hash returns empty hash on invalid JSON" do
    msg = @conversation.messages.create!(role: "ai", content: "Hi")
    msg.update_column(:metadata, "not-json") # rubocop:disable Rails/SkipsModelValidations
    assert_equal({}, msg.metadata_hash)
  end
end
