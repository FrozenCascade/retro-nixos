import QtQuick
import qs
import qs.components.bar.tools

// The row of session keys along the bottom of the lock window. Keys with `confirm: true` ask "SURE?"
// first (a second click within three seconds does it); sleep does not, since waking it up undoes it.
Row {
  id: row

  spacing: 8

  // one entry per key; remove or add here
  readonly property var keys: [
    { glyph: Glyphs.sleep, label: "SLEEP", run: () => SessionState.sleep(), tint: Theme.fg, confirm: false },
    { glyph: Glyphs.logout, label: "LOGOUT", run: () => SessionState.logout(), tint: Theme.fg, confirm: true },
    { glyph: Glyphs.restart, label: "RESTART", run: () => SessionState.restart(), tint: Theme.fg, confirm: true },
    { glyph: Glyphs.power, label: "SHUTDOWN", run: () => SessionState.shutdown(), tint: Theme.red, confirm: true }
  ]

  Repeater {
    model: row.keys

    Tile {
      required property var modelData

      width: (row.width - row.spacing * (row.keys.length - 1)) / row.keys.length
      compact: true
      confirm: modelData.confirm
      glyph: modelData.glyph
      label: modelData.label
      tint: modelData.tint
      labelSize: Theme.fontSize - 3
      onActivated: modelData.run()
    }
  }
}
