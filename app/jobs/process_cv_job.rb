# frozen_string_literal: true

class ProcessCvJob < ApplicationJob
  queue_as :default

  # Retry on transient API errors with exponential backoff.
  retry_on Anthropic::Errors::RateLimitError,      wait: :polynomially_longer, attempts: 5
  retry_on Anthropic::Errors::InternalServerError, wait: :polynomially_longer, attempts: 3
  retry_on Anthropic::Errors::APIConnectionError,  wait: :polynomially_longer, attempts: 3

  # Billing / bad request — won't recover on retry; discard and log.
  discard_on Anthropic::Errors::BadRequestError do |job, error|
    Rails.logger.error("[ProcessCvJob] Non-retryable API error for candidate #{job.arguments.first}: #{error.message}")
  end

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
