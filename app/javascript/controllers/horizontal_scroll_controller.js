import { Controller } from "@hotwired/stimulus"

const SCROLL_STEP = 80
const KEY_DIRECTIONS = {
  ArrowLeft: -1,
  ArrowRight: 1
}

export default class extends Controller {
  scrollWithArrowKey(event) {
    const direction = KEY_DIRECTIONS[event.key]

    if (!direction || event.target !== this.element || this.hasModifier(event)) return
    if (this.element.scrollWidth <= this.element.clientWidth) return

    event.preventDefault()
    this.element.scrollBy({ left: direction * SCROLL_STEP, behavior: "auto" })
  }

  hasModifier(event) {
    return event.altKey || event.ctrlKey || event.metaKey || event.shiftKey
  }
}
