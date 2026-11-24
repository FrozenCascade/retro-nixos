import QtQuick
import "style"

// Sleep, restart and shut down along the bottom of the window. Restart and shut down ask "SURE?" first.
Row {
  id: row

  spacing: 8

  // Nerd Font code points (the same icons the shell uses); one entry per key
  readonly property var keys: [
    { glyph: String.fromCodePoint(0xF04B2), label: "SLEEP", confirm: false, tint: Skin.fg, run: () => sddm.suspend(), ok: sddm.canSuspend },
    { glyph: String.fromCodePoint(0xF0709), label: "RESTART", confirm: true, tint: Skin.fg, run: () => sddm.reboot(), ok: sddm.canReboot },
    { glyph: String.fromCodePoint(0xF0425), label: "SHUTDOWN", confirm: true, tint: Skin.red, run: () => sddm.powerOff(), ok: sddm.canPowerOff }
  ]

  Repeater {
    model: row.keys

    Key {
      required property var modelData

      visible: modelData.ok
      width: (row.width - row.spacing * (row.keys.length - 1)) / row.keys.length
      height: 56
      glyph: modelData.glyph
      label: modelData.label
      confirm: modelData.confirm
      tint: modelData.tint
      onActivated: modelData.run()
    }
  }
}
