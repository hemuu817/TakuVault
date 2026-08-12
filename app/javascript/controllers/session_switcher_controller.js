import { Controller } from "@hotwired/stimulus"

const REQUIRED_TARGETS = ["list", "detail", "loading", "error", "retry"]

export default class extends Controller {
  static targets = REQUIRED_TARGETS

  connect() {
    this.requestToken = 0
    this.abortController = null
    this.retryUrl = null
    this.beforeCache = this.cleanup.bind(this)
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.cleanup()
  }

  select(event) {
    const link = event.currentTarget
    if (!this.shouldHandle(event, link)) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.switchTo(new URL(link.href, window.location.href))
  }

  retry(event) {
    event.preventDefault()
    if (this.retryUrl) this.switchTo(new URL(this.retryUrl))
  }

  async switchTo(targetUrl) {
    const token = ++this.requestToken
    this.abortController?.abort()
    const abortController = new AbortController()
    this.abortController = abortController
    this.retryUrl = null
    this.setTemporaryState({ loading: true, error: false, retry: false })

    try {
      const response = await fetch(targetUrl.href, {
        credentials: "same-origin",
        headers: { Accept: "text/html" },
        signal: abortController.signal
      })
      const replacement = await this.validatedWorkspace(response, targetUrl)
      if (!this.isCurrent(token)) return

      this.commit(replacement, targetUrl)
    } catch (error) {
      if (!this.isCurrent(token) || error?.name === "AbortError") return

      this.retryUrl = targetUrl.href
      this.setTemporaryState({ loading: false, error: true, retry: true })
    } finally {
      if (this.isCurrent(token)) this.abortController = null
    }
  }

  shouldHandle(event, link) {
    if (event.defaultPrevented || event.button !== 0) return false
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false
    if (link.hasAttribute("download")) return false
    if (link.target && link.target.toLowerCase() !== "_self") return false

    const targetUrl = new URL(link.href, window.location.href)
    return targetUrl.origin === window.location.origin
  }

  async validatedWorkspace(response, targetUrl) {
    if (!response.ok || response.redirected) throw new Error("Unexpected response")

    const responseUrl = new URL(response.url, window.location.href)
    if (responseUrl.origin !== window.location.origin || responseUrl.href !== targetUrl.href) {
      throw new Error("Unexpected response URL")
    }

    const contentType = response.headers.get("Content-Type") || ""
    if (!/^text\/html(?:\s*;|$)/i.test(contentType)) throw new Error("Unexpected content type")

    const documentFromResponse = new DOMParser().parseFromString(await response.text(), "text/html")
    const workspaces = documentFromResponse.querySelectorAll("#session-workspace")
    if (workspaces.length !== 1) throw new Error("Invalid workspace count")

    const workspace = workspaces[0]
    const controllers = (workspace.dataset.controller || "").split(/\s+/)
    if (!controllers.includes("session-switcher")) throw new Error("Missing controller")

    for (const target of REQUIRED_TARGETS) {
      if (workspace.querySelectorAll(`[data-session-switcher-target~="${target}"]`).length !== 1) {
        throw new Error(`Invalid ${target} target`)
      }
    }

    return document.importNode(workspace, true)
  }

  commit(replacement, targetUrl) {
    const previousUrl = window.location.href
    const previousState = history.state
    const previousWorkspace = this.element

    try {
      history.replaceState(previousState, "", targetUrl.href)
    } catch (error) {
      throw new Error("URL update failed", { cause: error })
    }

    try {
      previousWorkspace.replaceWith(replacement)
    } catch (error) {
      this.rollback(previousWorkspace, replacement, previousUrl, previousState)
      throw new Error("Workspace replacement failed", { cause: error })
    }
  }

  rollback(previousWorkspace, replacement, previousUrl, previousState) {
    try {
      if (!previousWorkspace.isConnected && replacement.isConnected) replacement.replaceWith(previousWorkspace)
      history.replaceState(previousState, "", previousUrl)
    } catch (_rollbackError) {
      window.location.replace(previousUrl)
    }
  }

  isCurrent(token) {
    return token === this.requestToken
  }

  cleanup() {
    ++this.requestToken
    this.abortController?.abort()
    this.abortController = null
    this.retryUrl = null
    this.setTemporaryState({ loading: false, error: false, retry: false })
  }

  setTemporaryState({ loading, error, retry }) {
    if (this.hasLoadingTarget) this.loadingTarget.hidden = !loading
    if (this.hasErrorTarget) this.errorTarget.hidden = !error
    if (this.hasRetryTarget) this.retryTarget.hidden = !retry
  }
}
