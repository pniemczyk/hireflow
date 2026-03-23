# frozen_string_literal: true

class Conversation < ApplicationRecord
  STATES = %w[in_progress completed failed].freeze

  belongs_to :candidate
  has_many :messages, -> { order(:position) }, dependent: :destroy, inverse_of: :conversation

  validates :state, inclusion: { in: STATES }

  # Marks the interview as successfully completed.
  def complete!
    update!(state: 'completed', completed_at: Time.current)
  end

  # Marks the interview as failed (failure threshold reached).
  def fail!
    update!(state: 'failed', completed_at: Time.current)
  end
end
