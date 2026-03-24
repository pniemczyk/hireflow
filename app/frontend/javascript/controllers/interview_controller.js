import { Controller } from '@hotwired/stimulus'

// Stimulus controller for the AI interview chat UI.
//
// Responsibilities:
//   - Submit form on Enter (Shift+Enter adds a new line)
//   - Show/hide loading spinner during the API round-trip
//   - Auto-scroll to the latest message after each update
//   - Per-message TTS: click avatar to play/pause/replay with word highlighting
//   - Speech-to-text dictation via Web Speech API
//
// Values:
//   synthesizeUrl  — the TTS synthesize endpoint (POST /tts/synthesize)
export default class extends Controller {
  static targets = ['form', 'input', 'submit', 'spinner', 'micBtn', 'micIcon', 'micDot']
  static values  = { synthesizeUrl: String }

  // WeakMap<buttonEl, { audio, words, wordTimer, currentIndex, blobUrl }>
  #speechData  = new WeakMap()
  #observer    = null
  #recognition = null
  #micActive   = false

  connect() {
    this.#observeMessages()
    this.#scrollToBottom()
    // Auto-play the last AI message already in the DOM on page load.
    const lastBtn = [...this.element.querySelectorAll('.ai-speak-btn')].at(-1)
    if (lastBtn) this.#startSpeech(lastBtn)
  }

  disconnect() {
    this.#observer?.disconnect()
    this.#stopMic()
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
    this.#stopMic()
  }

  // Called by data-action="turbo:submit-end->interview#onSubmitEnd"
  // Primary path for error responses (form stays in DOM). Success path is
  // handled by the MutationObserver when new messages are appended.
  onSubmitEnd() {
    this.#setLoading(false)
  }

  // Click handler for the speak button — routes based on current speech state.
  async toggleSpeech(event) {
    const btn   = event.currentTarget
    const state = btn.dataset.speechState || 'idle'

    if (state === 'idle' || state === 'ended') {
      await this.#startSpeech(btn)
    } else if (state === 'playing') {
      this.#pauseSpeech(btn)
    } else if (state === 'paused') {
      await this.#resumeSpeech(btn)
    }
    // 'loading' — ignore clicks while fetching
  }

  // Toggle speech-to-text dictation via Web Speech API.
  toggleMic() {
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech recognition is not supported in this browser. Try Chrome or Edge.')
      return
    }
    this.#micActive ? this.#stopMic() : this.#startMic()
  }

  // ─── private ─────────────────────────────────────────────────────────────────

  #setLoading(loading) {
    if (this.hasSubmitTarget)  this.submitTarget.disabled = loading
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.toggle('hidden', !loading)
    if (this.hasSubmitTarget)  this.submitTarget.classList.toggle('hidden',  loading)
  }

  // Watch #messages for newly appended AI messages.
  // When one appears, the round-trip is complete — reset loading + clear textarea.
  #observeMessages() {
    const messages = this.element.querySelector('#messages')
    if (!messages) return

    this.#observer = new MutationObserver((mutations) => {
      let newAiBtn = null
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue
          const btn = node.classList?.contains('ai-message')
            ? node.querySelector('.ai-speak-btn')
            : node.querySelector?.('.ai-message .ai-speak-btn')
          if (btn) newAiBtn = btn
        }
      }

      if (newAiBtn) {
        // New AI message — submission completed successfully.
        this.#setLoading(false)
        if (this.hasInputTarget) {
          this.inputTarget.value = ''
          this.inputTarget.focus()
        }
        this.#startSpeech(newAiBtn)
      }

      this.#scrollToBottom()
    })

    this.#observer.observe(messages, { childList: true, subtree: false })
  }

  #scrollToBottom() {
    window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' })
  }

  // Fetch TTS audio, build word spans, and start playback.
  async #startSpeech(btn) {
    const msgEl  = btn.closest('.ai-message')
    const textEl = msgEl?.querySelector('.ai-text')
    const text   = textEl?.textContent?.trim()
    if (!text || !this.synthesizeUrlValue) return

    // Replay: reuse cached audio if available.
    const cached = this.#speechData.get(btn)
    if (cached?.audio && btn.dataset.speechState === 'ended') {
      cached.audio.currentTime = 0
      cached.currentIndex      = -1
      this.#renderWords(textEl, cached.words)
      this.#setState(btn, 'playing')
      this.#startWordTracking(btn, cached, textEl)
      await cached.audio.play()
      return
    }

    this.#setState(btn, 'loading')

    try {
      const res = await fetch(this.synthesizeUrlValue, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.#csrfToken },
        body:    JSON.stringify({ text })
      })
      if (!res.ok) { this.#setState(btn, 'idle'); return }

      const data  = await res.json()
      const words = this.#buildWords(text, data.alignment)

      // Decode base64 → Blob URL
      const binary  = atob(data.audio_base64)
      const bytes   = new Uint8Array(binary.length)
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
      const audio   = new Audio(URL.createObjectURL(new Blob([bytes], { type: 'audio/mpeg' })))

      const entry = { audio, words, wordTimer: null, currentIndex: -1 }
      this.#speechData.set(btn, entry)

      audio.addEventListener('ended', () => {
        clearInterval(entry.wordTimer)
        this.#setState(btn, 'ended')
        textEl?.querySelectorAll('.word-token').forEach(el => {
          el.classList.remove('word-current')
          el.classList.add('word-spoken')
        })
      })

      audio.addEventListener('error', () => {
        clearInterval(entry.wordTimer)
        this.#setState(btn, 'idle')
      })

      this.#renderWords(textEl, words)
      this.#setState(btn, 'playing')
      this.#startWordTracking(btn, entry, textEl)
      await audio.play()
    } catch {
      this.#setState(btn, 'idle')
    }
  }

  #pauseSpeech(btn) {
    const entry = this.#speechData.get(btn)
    if (!entry?.audio) return
    entry.audio.pause()
    clearInterval(entry.wordTimer)
    this.#setState(btn, 'paused')
  }

  async #resumeSpeech(btn) {
    const entry  = this.#speechData.get(btn)
    const msgEl  = btn.closest('.ai-message')
    const textEl = msgEl?.querySelector('.ai-text')
    if (!entry?.audio) return
    this.#setState(btn, 'playing')
    this.#startWordTracking(btn, entry, textEl)
    await entry.audio.play()
  }

  // Parse ElevenLabs character-level alignment into word objects with timestamps.
  #buildWords(text, alignment) {
    if (!alignment?.characters) {
      return text.split(/\s+/).map(word => ({ word, start: 0, end: 9999 }))
    }

    const chars  = alignment.characters
    const starts = alignment.character_start_times_seconds
    const ends   = alignment.character_end_times_seconds
    const words  = []
    let word = '', wordStart = null, wordEnd = null

    for (let i = 0; i < chars.length; i++) {
      const ch = chars[i]
      if (ch === ' ' || ch === '\n') {
        if (word) { words.push({ word, start: wordStart, end: wordEnd }); word = ''; wordStart = null }
      } else {
        if (wordStart === null) wordStart = starts[i]
        wordEnd = ends[i]
        word   += ch
      }
    }
    if (word) words.push({ word, start: wordStart, end: wordEnd })
    return words
  }

  #renderWords(textEl, words) {
    if (!textEl) return
    textEl.innerHTML = words
      .map((w, i) => `<span class="word-token" data-idx="${i}">${w.word}</span>`)
      .join(' ')
  }

  #startWordTracking(btn, entry, textEl) {
    clearInterval(entry.wordTimer)
    entry.wordTimer = setInterval(() => {
      if (!entry.audio) return
      const t     = entry.audio.currentTime
      let   found = -1

      for (let i = 0; i < entry.words.length; i++) {
        if (t >= entry.words[i].start && t <= entry.words[i].end) { found = i; break }
      }

      if (found !== entry.currentIndex) {
        entry.currentIndex = found
        textEl?.querySelectorAll('.word-token').forEach((el, i) => {
          el.classList.remove('word-current', 'word-spoken')
          if (i === found)    el.classList.add('word-current')
          else if (i < found) el.classList.add('word-spoken')
        })
      }
    }, 40)
  }

  // Icon visibility is handled entirely by CSS via data-speech-state.
  #setState(btn, state) {
    btn.dataset.speechState = state
  }

  #startMic() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    this.#recognition = new SR()
    this.#recognition.continuous    = true
    this.#recognition.interimResults = true
    this.#recognition.lang           = 'en-US'

    let committed = this.inputTarget.value

    this.#recognition.onresult = (event) => {
      let interim = ''
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const t = event.results[i][0].transcript
        if (event.results[i].isFinal) committed += t
        else interim += t
      }
      this.inputTarget.value = committed + interim
    }

    this.#recognition.onend  = () => { this.inputTarget.value = committed; this.#setMicState(false) }
    this.#recognition.onerror = () => this.#stopMic()

    this.#recognition.start()
    this.#setMicState(true)
  }

  #stopMic() {
    this.#recognition?.stop()
    this.#recognition = null
    this.#setMicState(false)
  }

  #setMicState(active) {
    this.#micActive = active
    if (!this.hasMicBtnTarget) return
    this.micIconTarget.classList.toggle('hidden',               active)
    this.micDotTarget.classList.toggle('hidden',               !active)
    this.micBtnTarget.classList.toggle('border-red-400/60',    active)
    this.micBtnTarget.classList.toggle('text-red-400',         active)
    this.micBtnTarget.classList.toggle('border-outline-variant/30', !active)
    this.micBtnTarget.classList.toggle('text-on-surface-variant',   !active)
    this.micBtnTarget.setAttribute('aria-label', active ? 'Stop dictation' : 'Dictate answer')
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content ?? ''
  }
}
