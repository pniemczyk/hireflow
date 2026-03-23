import { Controller } from '@hotwired/stimulus'

// Stimulus controller for the AI interview chat UI.
//
// Responsibilities:
//   - Submit form on Enter (Shift+Enter adds a new line)
//   - Show/hide loading spinner during the API round-trip
//   - Auto-scroll to the latest message after each update
//   - Trigger TTS auto-play on new AI messages via MutationObserver
//
// Values:
//   synthesizeUrl  — the TTS synthesize endpoint (POST /tts/synthesize)
export default class extends Controller {
  static targets = ['form', 'input', 'submit', 'spinner', 'waveform', 'lastAiMessage']
  static values  = { synthesizeUrl: String }

  connect() {
    this.#observeMessages()
    this.#scrollToBottom()
  }

  disconnect() {
    this.#observer?.disconnect()
  }

  // Submit on Enter; allow Shift+Enter for new lines.
  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  // Called by data-action="turbo:submit-start->interview#onSubmitStart"
  onSubmitStart() {
    this.#setLoading(true)
  }

  // Called by data-action="turbo:submit-end->interview#onSubmitEnd"
  onSubmitEnd() {
    this.#setLoading(false)
    this.inputTarget.value = ''
    this.inputTarget.focus()
  }

  // ─── private ─────────────────────────────────────────────────────────────────

  #observer = null

  #setLoading(loading) {
    this.submitTarget.disabled = loading
    this.spinnerTarget.classList.toggle('hidden', !loading)
    this.submitTarget.classList.toggle('hidden',  loading)
  }

  // Watch the #messages container for newly appended AI messages and auto-play TTS.
  #observeMessages() {
    const messages = this.element.querySelector('#messages')
    if (!messages) return

    this.#observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue
          const autoplayEl = node.dataset?.autoplay
            ? node
            : node.querySelector('[data-autoplay]')
          if (autoplayEl) this.#playSpeech(autoplayEl)
        }
      }
      this.#scrollToBottom()
    })

    this.#observer.observe(messages, { childList: true, subtree: true })
  }

  #scrollToBottom() {
    window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' })
  }

  // Fetch audio from TTS endpoint and play it back.
  async #playSpeech(el) {
    const text = el.querySelector('p')?.textContent?.trim()
    if (!text || !this.synthesizeUrlValue) return

    const waveform = el.querySelector('[data-interview-target="waveform"]')

    try {
      const res  = await fetch(this.synthesizeUrlValue, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.#csrfToken },
        body:    JSON.stringify({ text })
      })
      if (!res.ok) return
      const data = await res.json()

      const audio = new Audio(`data:audio/mpeg;base64,${data.audio_base64}`)
      waveform?.classList.remove('hidden')
      audio.addEventListener('ended',  () => waveform?.classList.add('hidden'))
      audio.addEventListener('error',  () => waveform?.classList.add('hidden'))
      audio.play()
    } catch {
      waveform?.classList.add('hidden')
    }
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content ?? ''
  }
}
