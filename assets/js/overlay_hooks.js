export const Hooks = {
  OverlayPlayback: {
    mounted() {
      this.mediaEl = null

      this.handleEvent("play_command", payload => {
        const tag = payload.media_type === "video" ? "video" : "audio"

        if (!this.mediaEl || this.mediaEl.tagName.toLowerCase() !== tag) {
          if (this.mediaEl) this.mediaEl.remove()
          this.mediaEl = document.createElement(tag)
          this.mediaEl.autoplay = true
          this.mediaEl.playsInline = true
          this.el.appendChild(this.mediaEl)
        }

        this.mediaEl.src = payload.url
        this.mediaEl.load()
        this.mediaEl.play().catch(() => {})
      })
    }
  }
}
