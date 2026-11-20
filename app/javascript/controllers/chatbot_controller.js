import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chatbot"
export default class extends Controller {
  static targets = [ "launcher", "panel", "log", "question", "option" ]

  toggle() {
    if (this.panelTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.hidden = false
    this.launcherTarget.setAttribute("aria-expanded", "true")
    this.focusFirstOption()
  }

  close() {
    if (this.panelTarget.hidden) {
      return
    }

    this.panelTarget.hidden = true
    this.launcherTarget.setAttribute("aria-expanded", "false")
    this.launcherTarget.focus()
  }

  openFromTrigger(event) {
    const trigger = event.target.closest("[data-chatbot-open]")
    if (trigger === null) {
      return
    }

    if (trigger.hasAttribute("data-turbo-stream")) {
      this.awaitReply()
    }
    this.open()
  }

  awaitReply() {
    this.awaitingReply = true
  }

  questionTargetConnected(question) {
    const padding = parseFloat(getComputedStyle(this.logTarget).paddingTop)
    let behavior = "smooth"
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      behavior = "auto"
    }

    this.logTarget.scrollTo({ top: question.offsetTop - padding, behavior: behavior })
  }

  optionTargetConnected() {
    if (!this.awaitingReply) {
      return
    }

    this.awaitingReply = false
    requestAnimationFrame(() => this.focusFirstOption())
  }

  focusFirstOption() {
    if (this.optionTargets.length > 0) {
      this.optionTargets[0].focus()
    }
  }
}
