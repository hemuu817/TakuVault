import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "error"]

  retry(event) {
    event.preventDefault()
    this.element.reload()
  }

  loading() {
    this.loadingTarget.hidden = false
    this.errorTarget.hidden = true
  }

  loaded() {
    this.loadingTarget.hidden = true
    this.errorTarget.hidden = true
  }

  failed(event) {
    event.preventDefault()
    this.loadingTarget.hidden = true
    this.errorTarget.hidden = false
  }
}
