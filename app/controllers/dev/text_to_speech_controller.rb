# frozen_string_literal: true

module Dev
  # Prototype page for testing ElevenLabs text-to-speech.
  # Only accessible in development. Delegates the actual synthesis
  # to TtsController so the production path stays in sync.
  class TextToSpeechController < TtsController
    def show; end
  end
end
