pragma Singleton
import Quickshell
import QtQuick

// Icons from the Nerd Font (Material Design set), by code point. If one looks wrong in your font,
// change its number here and every place that uses it follows.
Singleton {
  function g(code) {
    return String.fromCodePoint(code);
  }

  readonly property string volOff: g(0xF0581)
  readonly property string volLow: g(0xF057F)
  readonly property string volMid: g(0xF0580)
  readonly property string volHigh: g(0xF057E)
  readonly property string mic: g(0xF036C)
  readonly property string micOff: g(0xF036D)
  readonly property string bell: g(0xF009A)
  readonly property string bellOff: g(0xF009B)
  readonly property string bellRing: g(0xF009E)
  readonly property string coffee: g(0xF0176)
  readonly property string lock: g(0xF033E)
  readonly property string sleep: g(0xF04B2)
  readonly property string logout: g(0xF0343)
  readonly property string restart: g(0xF0709)
  readonly property string power: g(0xF0425)
  readonly property string trash: g(0xF01B4)
  readonly property string close: g(0xF0156)
  readonly property string key: g(0xF0306)

  // Connections window and bar button (Material Design set; if one looks wrong, change its number)
  readonly property string wifi1: g(0xF091F)
  readonly property string wifi2: g(0xF0922)
  readonly property string wifi3: g(0xF0925)
  readonly property string wifi4: g(0xF0928)
  readonly property string wifiNone: g(0xF091E)
  readonly property string wifiOff: g(0xF092B)
  readonly property string bluetooth: g(0xF00AF)
  readonly property string bluetoothOff: g(0xF00B2)
  readonly property string airplane: g(0xF001D)
  readonly property string vpn: g(0xF0582)
  readonly property string phone: g(0xF011C)
  readonly property string tablet: g(0xF04F7)
  readonly property string laptop: g(0xF0322)
  readonly property string upload: g(0xF0552)

  // Bluetooth device kinds (the names come from lib/net.js btKind)
  readonly property string headphones: g(0xF02CB)
  readonly property string keyboard: g(0xF030C)
  readonly property string mouse: g(0xF037D)
  readonly property string speaker: g(0xF04C3)
  readonly property string gamepad: g(0xF02B4)

  // Display window and bar button
  readonly property string bulbOutline: g(0xF0336)
  readonly property string bulb: g(0xF0335)
  readonly property string bulbOn: g(0xF06E8)
  readonly property string moon: g(0xF0594)

  // Music wallpaper
  readonly property string music: g(0xF0387)
  readonly property string skipPrevious: g(0xF04AE)
  readonly property string skipNext: g(0xF04AD)
  readonly property string play: g(0xF040A)
  readonly property string pause: g(0xF03E4)
}
