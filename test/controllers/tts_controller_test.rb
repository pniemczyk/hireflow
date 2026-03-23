# frozen_string_literal: true

require "test_helper"

class TtsControllerTest < ActionDispatch::IntegrationTest
  ELEVENLABS_URL = "https://api.elevenlabs.io"

  # ── Happy path ───────────────────────────────────────────────────────────────

  test "returns audio_base64 and alignment on success" do
    stub_elevenlabs_success

    post tts_synthesize_path, params: { text: "Hello world" }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "AUDIO_BASE64", body["audio_base64"]
    assert body.key?("alignment")
  end

  # ── Validation ───────────────────────────────────────────────────────────────

  test "returns 422 when text is blank" do
    post tts_synthesize_path, params: { text: "" }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "Text is required", body["error"]
  end

  test "returns 422 when text param is missing" do
    post tts_synthesize_path, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "Text is required", body["error"]
  end

  # ── ElevenLabs error propagation ─────────────────────────────────────────────

  test "returns 422 when ElevenLabs returns a non-success status" do
    stub_elevenlabs_error(status: 401, body: '{"detail":"Invalid API key"}')

    post tts_synthesize_path, params: { text: "Hello" }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match(/ElevenLabs error 401/, body["error"])
  end

  test "returns 422 when ElevenLabs is unreachable" do
    stub_request(:post, /api\.elevenlabs\.io/).to_raise(Net::OpenTimeout)

    post tts_synthesize_path, params: { text: "Hello" }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["error"].present?
  end

  private

  def stub_elevenlabs_success
    stub_request(:post, /api\.elevenlabs\.io/)
      .to_return(
        status: 200,
        body:   { audio_base64: "AUDIO_BASE64", alignment: { chars: [], char_start_times_ms: [] } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_elevenlabs_error(status:, body:)
    stub_request(:post, /api\.elevenlabs\.io/)
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end
end
