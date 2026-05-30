import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["session", "scene"]

  connect() {
    this.update()
  }

  update() {
    const sessionId = this.sessionTarget.value
    let selectedOptionVisible = false

    this.sceneTarget.querySelectorAll("option").forEach((option) => {
      const optionSessionId = option.dataset.sessionId
      const visible = option.value === "" || (sessionId !== "" && optionSessionId === sessionId)

      option.hidden = !visible
      option.disabled = !visible

      if (option.selected && visible) {
        selectedOptionVisible = true
      }
    })

    if (!selectedOptionVisible) {
      this.sceneTarget.value = ""
    }
  }
}
