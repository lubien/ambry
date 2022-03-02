// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "./vendor/some-package.js"
//
// Alternatively, you can `npm install some-package` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import topbar from '../vendor/topbar'
import Alpine from 'alpinejs'
import { ShakaPlayerHook } from './hooks/shaka_player'
import { MediaControlsHook } from './hooks/media_controls'
import { SpeedSliderHook } from './hooks/speed_slider'
import { BookmarkButtonHook } from './hooks/bookmark_button'
import readMore from './alpine_data/read_more'

const browserId = window.crypto
  .getRandomValues(new Uint32Array(1))[0]
  .toString(16)

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content')

const liveSocket = new LiveSocket('/live', Socket, {
  params: { _csrf_token: csrfToken, browser_id: browserId },
  hooks: {
    mediaPlayer: ShakaPlayerHook,
    mediaControls: MediaControlsHook,
    speedSlider: SpeedSliderHook,
    bookmarkButton: BookmarkButtonHook
  },
  dom: {
    onBeforeElUpdated (from, to) {
      if (from._x_dataStack) {
        Alpine.clone(from, to)
      }
    }
  }
})

const dark = localStorage.theme === 'dark' || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)

window.formatTimecode = (secs) => {
  var sec_num = parseInt(secs, 10)
  var hours = Math.floor(sec_num / 3600)
  var minutes = Math.floor(sec_num / 60) % 60
  var seconds = sec_num % 60

  return [hours, minutes, seconds]
    .map(v => v < 10 ? "0" + v : v)
    .filter((v,i) => v !== "00" || i > 0)
    .join(":")
}

// Setup Alpine.js
window.Alpine = Alpine

Alpine.data('readMore', readMore)
Alpine.store('search', { open: false, query: "" })
Alpine.store('menu', { open: false })
Alpine.store('player', { playing: false, playbackPercentage: '0.00', duration: 0 })
Alpine.start()

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: dark ? '#A3E635' : '#84CC16' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', info => topbar.show())
window.addEventListener('phx:page-loading-stop', info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
