import Quickshell
import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// The WALLPAPER tab: one card per monitor (mode, picture, mode options, decor).
// The wallpaper itself is drawn by components/wallpaper/WallpaperLayer.qml.
Flickable {
  id: flick

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 10

    SectionHead { width: parent.width; text: "MONITORS" }

    Repeater {
      // the primary first; settings belong to the role, so a laptop that becomes primary keeps the primary's look
      model: Array.from(Quickshell.screens).sort((a, b) => (WallpaperState.roleOf(a.name) === "primary" ? 0 : 1) - (WallpaperState.roleOf(b.name) === "primary" ? 0 : 1))

      delegate: MonitorWallpaperCard {
        required property var modelData
        width: col.width
        monitor: modelData
      }
    }

    SharedWallpaperCard { width: parent.width }
    SddmWallpaperCard { width: parent.width }
  }
}
