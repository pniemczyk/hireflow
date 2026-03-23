import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['textarea', 'output', 'playBtn', 'stopBtn', 'waveform', 'status']
  static values  = { synthesizeUrl: String }

  connect () {
    this._words          = []
    this._currentIndex   = -1
    this._isPlaying      = false
  }

  disconnect () {
    this._teardown()
  }

  // ── Public actions ────────────────────────────────────────────────

  async play () {
    const text = this.textareaTarget.value.trim()
    if (!text || this._isPlaying) return

    this._setStatus('Synthesizing…')
    this.playBtnTarget.disabled = true
    this.stopBtnTarget.disabled = false
    this.outputTarget.innerHTML = ''

    try {
      const res  = await fetch(this.synthesizeUrlValue, {
        method:  'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ text })
      })

      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error || `HTTP ${res.status}`)
      }

      const data = await res.json()
      await this._playAudio(data)
    } catch (e) {
      this._setStatus(`Error: ${e.message}`)
      this.playBtnTarget.disabled = false
      this.stopBtnTarget.disabled = true
    }
  }

  stop () {
    this._teardown()
    this._setIdle()
  }

  // ── Private ───────────────────────────────────────────────────────

  async _playAudio (data) {
    // Decode base64 audio → Blob URL
    const binary = atob(data.audio_base64)
    const bytes  = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    const blob    = new Blob([bytes], { type: 'audio/mpeg' })
    const blobUrl = URL.createObjectURL(blob)

    // Wire Web Audio for real-time waveform
    this._audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    this._audio    = new Audio(blobUrl)

    const mediaSource = this._audioCtx.createMediaElementSource(this._audio)
    this._analyser    = this._audioCtx.createAnalyser()
    this._analyser.fftSize = 64
    mediaSource.connect(this._analyser)
    this._analyser.connect(this._audioCtx.destination)

    // Build word list + render spans
    this._buildWords(this.textareaTarget.value.trim(), data.alignment)

    this._audio.onended = () => this._onEnd()
    this._audio.onerror = () => {
      this._setStatus('Audio error')
      this._setIdle()
    }

    await this._audio.play()
    this._isPlaying = true
    this._setStatus('Speaking…')

    this._startWaveform()
    this._startWordTracking()
  }

  _buildWords (text, alignment) {
    const chars  = alignment.characters
    const starts = alignment.character_start_times_seconds
    const ends   = alignment.character_end_times_seconds

    this._words = []
    let word = '', wordStart = null, wordEnd = null

    for (let i = 0; i < chars.length; i++) {
      const ch = chars[i]
      if (ch === ' ' || ch === '\n') {
        if (word) {
          this._words.push({ word, start: wordStart, end: wordEnd })
          word = ''
          wordStart = null
        }
      } else {
        if (wordStart === null) wordStart = starts[i]
        wordEnd = ends[i]
        word   += ch
      }
    }
    if (word) this._words.push({ word, start: wordStart, end: wordEnd })

    // Render spans
    this.outputTarget.innerHTML = this._words
      .map((w, i) => `<span class="word-token" data-idx="${i}">${w.word}</span>`)
      .join(' ')

    this._currentIndex = -1
  }

  _startWordTracking () {
    this._wordTimer = setInterval(() => {
      if (!this._isPlaying || !this._audio) return

      const t     = this._audio.currentTime
      let   found = -1

      for (let i = 0; i < this._words.length; i++) {
        if (t >= this._words[i].start && t <= this._words[i].end) {
          found = i
          break
        }
      }

      if (found !== this._currentIndex) {
        this._currentIndex = found
        this._highlightWord(found)
      }
    }, 40)
  }

  _highlightWord (index) {
    this.outputTarget.querySelectorAll('.word-token').forEach((el, i) => {
      el.classList.remove('word-current', 'word-spoken')
      if (i === index)  el.classList.add('word-current')
      else if (i < index) el.classList.add('word-spoken')
    })

    if (index >= 0) {
      const el = this.outputTarget.querySelector(`[data-idx="${index}"]`)
      el?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
    }
  }

  _startWaveform () {
    const bars   = this.waveformTarget.querySelectorAll('.wave-bar')
    const count  = bars.length
    const binLen = this._analyser.frequencyBinCount

    const draw = () => {
      if (!this._isPlaying) return
      this._rafId = requestAnimationFrame(draw)

      const freq = new Uint8Array(binLen)
      this._analyser.getByteFrequencyData(freq)

      bars.forEach((bar, i) => {
        const bin   = Math.floor((i / count) * (binLen / 2))
        const level = freq[bin] / 255
        const h     = Math.max(3, level * 100)
        bar.style.height  = `${h}%`
        bar.style.opacity = (0.25 + level * 0.75).toFixed(2)
      })
    }
    draw()
  }

  _onEnd () {
    clearInterval(this._wordTimer)
    cancelAnimationFrame(this._rafId)
    this._isPlaying = false

    // Mark everything spoken
    this.outputTarget.querySelectorAll('.word-token').forEach(el => {
      el.classList.remove('word-current')
      el.classList.add('word-spoken')
    })

    // Collapse waveform bars
    this.waveformTarget.querySelectorAll('.wave-bar').forEach(bar => {
      bar.style.height  = '3px'
      bar.style.opacity = '0.25'
    })

    this._setIdle()
  }

  _teardown () {
    clearInterval(this._wordTimer)
    cancelAnimationFrame(this._rafId)

    if (this._audio) {
      this._audio.pause()
      this._audio.src = ''
      this._audio     = null
    }
    if (this._audioCtx) {
      this._audioCtx.close()
      this._audioCtx = null
    }

    this._isPlaying = false
  }

  _setIdle () {
    this._setStatus('')
    this.playBtnTarget.disabled = false
    this.stopBtnTarget.disabled = true
  }

  _setStatus (text) {
    this.statusTarget.textContent = text
  }
}
