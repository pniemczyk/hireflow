import { Controller } from '@hotwired/stimulus'

// Voice input via Web Speech API.
// Supported: Chrome, Edge, Safari 14.1+
// Not supported: Firefox
//
// Usage:
//   data-controller="voice-input"
//   data-voice-input-target="output"   — <textarea> or <input> to write into
//   data-voice-input-target="micBtn"   — button that triggers toggle
//   data-voice-input-target="statusDot"— optional live-indicator dot
//   data-voice-input-lang-value="en-US"— optional BCP-47 language tag

export default class extends Controller {
  static targets = ['output', 'micBtn', 'statusDot']
  static values  = { lang: { type: String, default: 'en-US' } }

  #recognition = null
  #isRecording  = false
  #baseText     = ''        // committed text before / between utterances

  connect() {
    this.SpeechAPI = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!this.SpeechAPI) {
      this.#markUnsupported()
    }
  }

  disconnect() {
    this.#stop()
  }

  toggle() {
    if (!this.SpeechAPI) return
    this.#isRecording ? this.#stop() : this.#start()
  }

  // ─── private ──────────────────────────────────────────────────────────────

  #start() {
    this.#recognition = new this.SpeechAPI()
    this.#recognition.lang            = this.langValue
    this.#recognition.interimResults  = true
    this.#recognition.continuous      = true    // keep listening until user clicks stop

    // Save whatever is already in the textarea so we can append to it
    this.#baseText = this.outputTarget.value

    this.#recognition.onresult = (event) => {
      let final = '', interim = ''
      for (const result of event.results) {
        if (result.isFinal) final   += result[0].transcript
        else                interim += result[0].transcript
      }

      // Commit finals into baseText
      if (final) {
        const sep = this.#baseText ? ' ' : ''
        this.#baseText += sep + final.trim()
      }

      // Show committed + live interim together
      const sep = this.#baseText && interim ? ' ' : ''
      this.outputTarget.value = this.#baseText + sep + interim

      // Scroll textarea to bottom
      this.outputTarget.scrollTop = this.outputTarget.scrollHeight
    }

    this.#recognition.onerror = (event) => {
      // 'aborted' fires when we call stop() ourselves — not a real error
      if (event.error !== 'aborted') {
        console.warn('[voice-input] error:', event.error)
      }
      this.#stop()
    }

    this.#recognition.onend = () => {
      // If the user hasn't clicked stop, restart — some browsers end the session
      // after a long pause even with continuous: true
      if (this.#isRecording) {
        this.#recognition = null
        this.#start()
      }
    }

    this.#recognition.start()
    this.#isRecording = true
    this.#setRecordingState(true)
  }

  #stop() {
    if (this.#recognition) {
      this.#recognition.stop()
      this.#recognition = null
    }
    this.#isRecording = false
    this.#setRecordingState(false)
  }

  #setRecordingState(recording) {
    if (!this.hasMicBtnTarget) return

    this.micBtnTarget.classList.toggle('text-error',            recording)
    this.micBtnTarget.classList.toggle('text-on-surface-variant', !recording)
    this.micBtnTarget.setAttribute('aria-pressed', String(recording))

    if (this.hasStatusDotTarget) {
      this.statusDotTarget.classList.toggle('hidden',          !recording)
      this.statusDotTarget.classList.toggle('bg-error',         recording)
      this.statusDotTarget.classList.toggle('bg-secondary',    !recording)
    }
  }

  #markUnsupported() {
    if (!this.hasMicBtnTarget) return
    this.micBtnTarget.disabled = true
    this.micBtnTarget.classList.add('opacity-30', 'cursor-not-allowed')
    this.micBtnTarget.title = 'Voice input is not supported in this browser'
    // Surface the tooltip text target if present
    const tooltip = this.micBtnTarget.querySelector('[data-voice-tooltip]')
    if (tooltip) tooltip.textContent = 'Not supported in this browser'
  }
}
