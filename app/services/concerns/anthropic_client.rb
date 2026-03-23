# frozen_string_literal: true

# Provides a memoized Anthropic API client for service objects.
module AnthropicClient
  private

  def client
    @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end
end
