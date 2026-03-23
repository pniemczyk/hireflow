import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['canvas', 'dragOverlay', 'fileInput', 'fileNameBadge', 'fileNameText']

  // ─── file input ────────────────────────────────────────────────────────────

  uploadShortcut() {
    this.fileInputTarget.click()
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (!file) return
    this._showFileName(file.name)
  }

  // ─── drag & drop ───────────────────────────────────────────────────────────

  dragOver(event) {
    event.preventDefault()
    if (!this._hasDragFiles(event)) return
    this.dragOverlayTarget.classList.remove('hidden')
  }

  dragLeave(event) {
    if (this.canvasTarget.contains(event.relatedTarget)) return
    this.dragOverlayTarget.classList.add('hidden')
  }

  drop(event) {
    event.preventDefault()
    this.dragOverlayTarget.classList.add('hidden')

    const file = event.dataTransfer.files[0]
    if (!file) return

    const dt = new DataTransfer()
    dt.items.add(file)
    this.fileInputTarget.files = dt.files
    this._showFileName(file.name)
  }

  // ─── private ───────────────────────────────────────────────────────────────

  _showFileName(name) {
    this.fileNameTextTarget.textContent = name
    this.fileNameBadgeTarget.classList.remove('hidden')
    this.fileNameBadgeTarget.classList.add('flex')
  }

  _hasDragFiles(event) {
    return Array.from(event.dataTransfer.types).includes('Files')
  }
}
