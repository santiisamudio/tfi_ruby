import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="name-tiles"
export default class extends Controller {
  static targets = [ "input", "row" ]
  static values = { minimum: Number }

  render() {
    const name = this.inputTarget.value.trim()
    const letters = Array.from(name)
    const filledBefore = this.rowTarget.querySelectorAll(".tile:not(.tile--empty)").length

    this.rowTarget.innerHTML = ""

    letters.forEach((letter, index) => {
      const isNew = index >= filledBefore
      this.rowTarget.appendChild(this.createTile(letter, isNew))
    })

    for (let i = letters.length; i < this.minimumValue; i++) {
      this.rowTarget.appendChild(this.createTile(null, false))
    }

    this.rowTarget.appendChild(this.createEnumeration(name))
  }

  use(event) {
    this.inputTarget.value = event.params.name
    this.render()
    this.inputTarget.focus()
  }

  createTile(letter, isNew) {
    const tile = document.createElement("span")
    tile.classList.add("tile")

    if (letter === null) {
      tile.classList.add("tile--empty")
    } else if (letter === " ") {
      tile.classList.add("tile--block")
    } else {
      tile.textContent = letter
    }

    if (isNew) {
      tile.classList.add("tile--fresh")
    }

    return tile
  }

  createEnumeration(name) {
    const enumeration = document.createElement("span")
    enumeration.classList.add("tile-row__enumeration")

    const words = name.split(" ").filter(word => word !== "")
    if (words.length > 0) {
      const lengths = words.map(word => Array.from(word).length)
      enumeration.textContent = "(" + lengths.join(", ") + ")"
    }

    return enumeration
  }
}
