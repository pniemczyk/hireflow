ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "minitest/reporters"

Minitest::Reporters.use! [ Minitest::Reporters::DefaultReporter.new(color: true) ]

WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Stub the Anthropic Messages API with a successful text response.
    #
    # @param text [String] the text content the assistant should return
    def stub_anthropic_messages(text:)
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: {
            id:           "msg_test",
            type:         "message",
            role:         "assistant",
            content:      [ { type: "text", text: text } ],
            model:        "claude-opus-4-6",
            stop_reason:  "end_turn",
            stop_sequence: nil,
            usage:        { input_tokens: 100, output_tokens: 50 }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    # Stub the Anthropic Messages API to return an error response.
    #
    # @param status [Integer] HTTP status code
    # @param type   [String]  Anthropic error type string
    # @param message[String]  human-readable error message
    def stub_anthropic_error(status:, type:, message:)
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: status,
          body: { type: "error", error: { type: type, message: message } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
