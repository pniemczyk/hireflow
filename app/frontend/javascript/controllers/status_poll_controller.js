import { Controller } from '@hotwired/stimulus'

// Polls the status JSON endpoint and updates the UI to reflect the current
// processing state. Stops polling once a terminal state is reached.
//
// Values:
//   url      — the status endpoint to poll
//   interval — polling interval in ms (default: 2000)
export default class extends Controller {
  static targets = ['label', 'bar', 'card', 'resultPanel']
  static values  = {
    url:      String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.#poll()
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  // ─── private ─────────────────────────────────────────────────────────────────

  #timer = null

  async #poll() {
    try {
      const res  = await fetch(this.urlValue, { headers: { Accept: 'application/json' } })
      const data = await res.json()

      this.#update(data)

      if (!data.done) {
        this.#timer = setTimeout(() => this.#poll(), this.intervalValue)
      }
    } catch (err) {
      console.warn('[status-poll] fetch error:', err)
      this.#timer = setTimeout(() => this.#poll(), this.intervalValue * 2)
    }
  }

  #update(data) {
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = data.label
    }

    if (this.hasBarTarget) {
      this.barTarget.style.width = `${data.progress}%`
    }

    if (this.hasCardTarget) {
      this.cardTarget.dataset.status = data.status
    }

    if (data.done && data.evaluation && this.hasResultPanelTarget) {
      this.resultPanelTarget.innerHTML = this.#buildResultHtml(data.evaluation)
      this.resultPanelTarget.classList.remove('hidden')
    }
  }

  #buildResultHtml(ev) {
    const badge = { pass: 'text-secondary', partial: 'text-primary', fail: 'text-error' }
    const icon  = { pass: 'check-circle-2', partial: 'alert-circle', fail: 'x-circle' }

    const gaps = ev.gaps?.length
      ? `<ul class="mt-2 space-y-1">${ev.gaps.map(g => `<li class="flex items-start gap-2"><span class="opacity-40 mt-0.5">·</span>${g}</li>`).join('')}</ul>`
      : ''

    return `
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2 ${badge[ev.overall] ?? 'text-on-surface'}">
            <i data-lucide="${icon[ev.overall] ?? 'info'}" class="w-5 h-5"></i>
            <span class="font-headline font-bold capitalize">${ev.overall}</span>
          </div>
          <span class="text-2xl font-headline font-bold text-on-surface">${ev.score}<span class="text-on-surface-variant text-sm font-body font-normal">/100</span></span>
        </div>
        <p class="text-on-surface-variant text-sm leading-relaxed">${ev.summary}</p>
        ${gaps ? `<div class="text-sm text-on-surface-variant">${gaps}</div>` : ''}
      </div>
    `
  }
}
