export const Hooks = {
  OverlayPlayback: {
    mounted() {
      this.mediaEl = null
      this.queue = []

      this.handleEvent("play_media_item", payload => {
        console.log('got play media item')
        console.log(payload)
        this.queue.push(payload)
        this.playNext()
      })
    },

    playNext() {
      if (this.mediaEl || this.queue.length === 0) return

      const payload = this.queue.shift()
      const media = document.createElement(payload.media_type === "video" ? "video" : "audio")
      this.mediaEl = media
      media.playsInline = true

      const finish = () => {
        if (this.mediaEl !== media) return
        media.remove()
        this.mediaEl = null
        this.playNext()
      }

      media.addEventListener("ended", finish, {once: true})
      media.addEventListener("error", finish, {once: true})
      media.src = payload.url
      this.el.appendChild(media)
      media.play().catch(finish)
    },

    destroyed() {
      this.queue = []
      const media = this.mediaEl
      this.mediaEl = null
      if (media) {
        media.pause()
        media.remove()
      }
    }
  }
}
