# frozen_string_literal: true

# Base job for all Anthropic API operations.
# Provides shared retry/discard policy so subclasses don't repeat it.
class AnthropicJob < ApplicationJob
  retry_on Anthropic::Errors::RateLimitError,      wait: :polynomially_longer, attempts: 5
  retry_on Anthropic::Errors::InternalServerError, wait: :polynomially_longer, attempts: 3
  retry_on Anthropic::Errors::APIConnectionError,  wait: :polynomially_longer, attempts: 3

  discard_on Anthropic::Errors::BadRequestError do |job, error|
    Rails.logger.error("[#{job.class.name}] Non-retryable API error for candidate #{job.arguments.first}: #{error.message}")
  end
end
