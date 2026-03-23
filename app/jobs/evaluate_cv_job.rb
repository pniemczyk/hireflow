# frozen_string_literal: true

class EvaluateCvJob < AnthropicJob
  queue_as :default

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
