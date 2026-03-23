# frozen_string_literal: true

class EvaluateCvJob < ApplicationJob
  queue_as :default

  # Retry on transient API errors with exponential backoff.
  retry_on Anthropic::Errors::RateLimitError,      wait: :polynomially_longer, attempts: 5
  retry_on Anthropic::Errors::InternalServerError, wait: :polynomially_longer, attempts: 3
  retry_on Anthropic::Errors::APIConnectionError,  wait: :polynomially_longer, attempts: 3

  # Billing / bad request — won't recover on retry; discard and log.
  discard_on Anthropic::Errors::BadRequestError do |job, error|
    Rails.logger.error("[EvaluateCvJob] Non-retryable API error for candidate #{job.arguments.first}: #{error.message}")
  end

  # @param candidate_id [Integer]
  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)

    return unless candidate.can_transition_to?(:evaluating)

    candidate.transition_to!(:evaluating)

    result = CvEvaluator.new(candidate).call

    candidate.update!(evaluation_result: result.to_json)
    candidate.transition_to!(:evaluated)
  rescue CvEvaluator::Error => e
    Rails.logger.error("[EvaluateCvJob] Evaluation failed for candidate #{candidate_id}: #{e.message}")
    raise
  end
end
