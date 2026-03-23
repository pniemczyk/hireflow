import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['helpModal', 'dropdown', 'avatarWrapper']

  connect() {
    this._outsideClick = this._handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener('click', this._outsideClick)
  }

  openHelp() {
    this.helpModalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  closeHelp() {
    this.helpModalTarget.classList.add('hidden')
    document.body.style.overflow = ''
  }

  toggleDropdown() {
    const isHidden = this.dropdownTarget.classList.contains('hidden')
    if (isHidden) {
      this.dropdownTarget.classList.remove('hidden')
      // Close when clicking outside
      setTimeout(() => document.addEventListener('click', this._outsideClick), 0)
    } else {
      this._closeDropdown()
    }
  }

  _closeDropdown() {
    this.dropdownTarget.classList.add('hidden')
    document.removeEventListener('click', this._outsideClick)
  }

  _handleOutsideClick(event) {
    if (!this.avatarWrapperTarget.contains(event.target)) {
      this._closeDropdown()
    }
  }
}
