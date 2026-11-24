import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import "../calendar"

// The SYSTEM tab: a small fastfetch about this machine, and the power buttons at the bottom.
Item {
  id: tab

  InfoPanel {
    x: 0
    y: 0
    width: parent.width
    height: parent.height - power.height - 10
  }

  Column {
    id: power
    anchors.bottom: parent.bottom
    width: parent.width
    spacing: 6

    SectionHead { width: parent.width; text: "POWER" }

    Row {
      spacing: 6
      Tile { width: (power.width - 24) / 5; compact: true; labelSize: Theme.fontSize - 3; glyph: Glyphs.lock; label: "LOCK"; onActivated: SessionState.lock() }
      Tile { width: (power.width - 24) / 5; compact: true; labelSize: Theme.fontSize - 3; glyph: Glyphs.sleep; label: "SLEEP"; onActivated: SessionState.sleep() }
      Tile { width: (power.width - 24) / 5; compact: true; labelSize: Theme.fontSize - 3; glyph: Glyphs.logout; label: "LOGOUT"; confirm: true; onActivated: SessionState.logout() }
      Tile { width: (power.width - 24) / 5; compact: true; labelSize: Theme.fontSize - 3; glyph: Glyphs.restart; label: "RESTART"; confirm: true; onActivated: SessionState.restart() }
      Tile { width: (power.width - 24) / 5; compact: true; labelSize: Theme.fontSize - 3; glyph: Glyphs.power; label: "SHUTDOWN"; confirm: true; tint: Theme.red; onActivated: SessionState.shutdown() }
    }
  }
}
