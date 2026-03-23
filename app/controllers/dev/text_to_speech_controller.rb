# frozen_string_literal: true

require 'net/http'

module Dev
  # Prototype page for testing ElevenLabs text-to-speech.
  # Only accessible in development.
  class TextToSpeechController < ApplicationController
    VOICE_ID       =  ENV['ELEVENLABS_VOICE_ID'] # ElevenLabs "Rachel" (premade)
    ELEVENLABS_URL = 'https://api.elevenlabs.io'

    def show; end

    # Proxies a TTS request to ElevenLabs and returns audio_base64 + alignment
    # so the browser can play the audio and highlight words in sync.
    def synthesize
      text = params[:text].to_s.strip
      return render json: { error: 'Text is required' }, status: :unprocessable_entity if text.blank?

      render json: call_elevenlabs(text)
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def call_elevenlabs(text)
      uri  = URI("#{ELEVENLABS_URL}/v1/text-to-speech/#{VOICE_ID}/with-timestamps")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = true
      http.read_timeout = 30

      req = Net::HTTP::Post.new(uri)
      req['xi-api-key']    = ENV.fetch('ELEVENLABS_API_KEY')
      req['Content-Type']  = 'application/json'
      req.body = {
        text:           text,
        model_id:       'eleven_turbo_v2',
        voice_settings: { stability: 0.5, similarity_boost: 0.75 }
      }.to_json

      res = http.request(req)

      unless res.is_a?(Net::HTTPSuccess)
        raise "ElevenLabs error #{res.code}: #{res.body.truncate(300)}"
      end

      JSON.parse(res.body)
    end
  end
end
