import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "row", "checkbox", "roleSelect"]

  connect() {
    this.initialRows = [...this.rowTargets]
    this.baseKind = null
    this.beforeCache = this.resetBeforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.beforeCache)

    const firstChecked = this.checkboxTargets.find((checkbox) => checkbox.checked)
    if (firstChecked) {
      this.baseKind = this.rowFor(firstChecked).dataset.assetKind
      this.synchronize()
    } else {
      this.resetDisplay()
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  selectionChanged(event) {
    if (event.currentTarget.checked && this.baseKind === null) {
      this.baseKind = this.rowFor(event.currentTarget).dataset.assetKind
    }

    if (!this.checkboxTargets.some((checkbox) => checkbox.checked)) {
      this.baseKind = null
      this.resetDisplay()
      return
    }

    this.synchronize()
  }

  synchronize() {
    this.reorderRows()

    this.checkboxTargets.forEach((checkbox) => {
      const row = this.rowFor(checkbox)
      const isDifferentKind = row.dataset.assetKind !== this.baseKind

      checkbox.disabled = isDifferentKind
      row.classList.toggle("opacity-40", isDifferentKind)
    })

    this.updateRoleOptions()
  }

  reorderRows() {
    const orderedRows = [
      ...this.initialRows.filter((row) => row.dataset.assetKind === this.baseKind),
      ...this.initialRows.filter((row) => row.dataset.assetKind !== this.baseKind)
    ]

    orderedRows.forEach((row) => this.listTarget.append(row))
  }

  updateRoleOptions() {
    let selectedRoleIsAvailable = this.roleSelectTarget.value === ""

    this.roleSelectTarget.querySelectorAll("option").forEach((option) => {
      const candidateKinds = (option.dataset.candidateKinds || "").split(" ").filter(Boolean)
      const available = option.value === "" || candidateKinds.includes(this.baseKind)

      option.hidden = !available
      option.disabled = !available

      if (option.selected && available) {
        selectedRoleIsAvailable = true
      }
    })

    if (!selectedRoleIsAvailable) {
      this.roleSelectTarget.value = ""
    }
  }

  resetDisplay() {
    this.restoreInitialRows()

    this.checkboxTargets.forEach((checkbox) => {
      checkbox.disabled = false
      this.rowFor(checkbox).classList.remove("opacity-40")
    })

    this.roleSelectTarget.querySelectorAll("option").forEach((option) => {
      option.hidden = false
      option.disabled = false
    })
  }

  resetBeforeCache() {
    this.baseKind = null
    this.resetDisplay()
  }

  restoreInitialRows() {
    this.initialRows.forEach((row) => this.listTarget.append(row))
  }

  rowFor(checkbox) {
    return checkbox.closest("[data-uncategorized-kind-target~='row']")
  }
}
