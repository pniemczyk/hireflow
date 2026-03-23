# frozen_string_literal: true

class Candidate < ApplicationRecord
  # ── State machine ─────────────────────────────────────────────────────────────
  STATUSES = Candidate::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Candidate::StateMachine.initial_state
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  inquirer :status

  # ── Associations ──────────────────────────────────────────────────────────────
  belongs_to :job
  has_one_attached :cv_file

  # ── Parsed evaluation result (stored as JSON text) ────────────────────────────
  def evaluation
    return nil if evaluation_result.blank?
    JSON.parse(evaluation_result, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────
  def cv_provided?
    cv_file.attached? || cv_raw_text.present?
  end
end
