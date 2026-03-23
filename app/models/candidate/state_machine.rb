# frozen_string_literal: true

class Candidate::StateMachine
  include Statesman::Machine

  # ── States ────────────────────────────────────────────────────────────────────
  state :cv_processing,        initial: true  # file uploaded, AI extraction in progress
  state :ready_for_evaluating                 # cv_raw_text present, queued for evaluation
  state :evaluating                           # Claude is evaluating the CV against the scenario
  state :evaluated                            # evaluation stored; awaiting interview or decision
  state :interviewing                         # Stage 3 — AI interview loop (future)
  state :completed                            # interview finished (future)
  state :accepted                             # recruiter decision (future)
  state :rejected                             # recruiter decision or auto-fail (future)

  # ── Transitions ───────────────────────────────────────────────────────────────
  transition from: :cv_processing,        to: :ready_for_evaluating
  transition from: :ready_for_evaluating, to: :evaluating
  transition from: :evaluating,           to: %i[evaluated rejected]
  transition from: :evaluated,            to: %i[interviewing accepted rejected]
  transition from: :interviewing,         to: :completed
  transition from: :completed,            to: %i[accepted rejected]

  # Sync the status cache column after every transition.
  after_transition do |candidate, transition|
    candidate.update_column(:status, transition.to_state) # rubocop:disable Rails/SkipsModelValidations
  end
end
