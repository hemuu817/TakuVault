import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "detail"]

  select(event) {
    const link = event.currentTarget
    if (!this.shouldHandle(event, link)) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.switchTo(new URL(link.href, window.location.href))
  }

  async switchTo(targetUrl) {
    const response = await fetch(targetUrl.href, {
      credentials: "same-origin",
      headers: { Accept: "text/html" }
    })
    if (!response.ok || response.redirected) return

    const responseUrl = new URL(response.url, window.location.href)
    if (responseUrl.origin !== window.location.origin || responseUrl.href !== targetUrl.href) return

    const documentFromResponse = new DOMParser().parseFromString(await response.text(), "text/html")
    const workspaces = documentFromResponse.querySelectorAll("#session-workspace")
    if (workspaces.length !== 1) return

    history.replaceState(history.state, "", targetUrl.href)
    this.element.replaceWith(document.importNode(workspaces[0], true))
  }

  shouldHandle(event, link) {
    if (event.defaultPrevented || event.button !== 0) return false
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false
    if (link.hasAttribute("download")) return false
    if (link.target && link.target.toLowerCase() !== "_self") return false

    const targetUrl = new URL(link.href, window.location.href)
    return targetUrl.origin === window.location.origin
  }
}
