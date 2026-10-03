const {test} = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const path = require("node:path")

function mount() {
  const created = []
  const context = {
    document: {
      createElement(tag) {
        const listeners = {}
        const media = {
          tag, removed: false, paused: false,
          addEventListener(name, callback) { listeners[name] = callback },
          play() { return Promise.resolve() },
          pause() { this.paused = true },
          remove() { this.removed = true },
          emit(name) { listeners[name]() }
        }
        created.push(media)
        return media
      }
    }
  }
  const source = fs.readFileSync(path.join(__dirname, "../../assets/js/overlay_hooks.js"), "utf8")
  vm.runInNewContext(source.replace("export const Hooks =", "globalThis.Hooks ="), context)
  const hook = {...context.Hooks.OverlayPlayback,
    el: {appendChild() {}},
    handleEvent(name, callback) { this.receive = callback }
  }
  hook.mounted()
  return {hook, created}
}

test("plays audio and video in arrival order without interrupting", () => {
  const {hook, created} = mount()
  hook.receive({media_type: "audio", url: "first.mp3"})
  hook.receive({media_type: "video", url: "second.mp4"})
  hook.receive({media_type: "audio", url: "third.mp3"})
  assert.equal(created.length, 1)
  assert.equal(created[0].src, "first.mp3")
  assert.equal(created[0].removed, false)
  created[0].emit("ended")
  assert.equal(created[1].tag, "video")
  assert.equal(created[1].src, "second.mp4")
  created[0].emit("error") // A late event from the previous clip must not skip a clip.
  assert.equal(created.length, 2)
  created[1].emit("ended")
  assert.equal(created[2].src, "third.mp3")
  created[2].emit("ended")
  assert.equal(hook.mediaEl, null)
  assert.equal(hook.queue.length, 0)
})

test("failed media advances the queue", async () => {
  const {hook, created} = mount()
  hook.receive({media_type: "audio", url: "broken.mp3"})
  hook.receive({media_type: "audio", url: "rejected.mp3"})
  hook.receive({media_type: "audio", url: "last.mp3"})
  // Make the next clip reject playback when created.
  const originalCreate = created[0].play
  hook.el.appendChild = media => {
    media.play = media.src === "rejected.mp3"
      ? () => Promise.reject(new Error("Playback failed"))
      : originalCreate
  }
  created[0].emit("error")
  await Promise.resolve()
  assert.equal(hook.mediaEl.src, "last.mp3")
})

test("destroying the overlay stops playback and clears queued clips", () => {
  const {hook, created} = mount()
  hook.receive({media_type: "audio", url: "first.mp3"})
  hook.receive({media_type: "video", url: "second.mp4"})
  hook.destroyed()
  assert.equal(created[0].paused, true)
  assert.equal(created[0].removed, true)
  created[0].emit("ended")
  assert.equal(created.length, 1)
  assert.equal(hook.queue.length, 0)
})
