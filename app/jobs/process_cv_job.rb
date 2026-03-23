# frozen_string_literal: true

class ProcessCvJob < AnthropicJob
  queue_as :default

  # @param candidate_id [Integer]
  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)

    return unless candidate.cv_file.attached?
    return if candidate.cv_raw_text.present?

    text = CvProcessor.new(candidate).call
    candidate.update!(cv_raw_text: text)

    # Advance the state machine and kick off evaluation.
    candidate.transition_to!(:ready_for_evaluating)
    EvaluateCvJob.perform_now(candidate_id)
  rescue CvProcessor::Error => e
    Rails.logger.error("[ProcessCvJob] CV extraction failed for candidate #{candidate_id}: #{e.message}")
    raise
  end
end
