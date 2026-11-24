import QtQuick
import qs
import qs.components.shared

// A row of the theme's colour names to pick from; the chosen one is pressed in.
// `option` is the setting it changes for this monitor (see WallpaperState.defaults).
Flow {
  id: row

  required property string monitorName
  required property string option

  readonly property string current: WallpaperState.cfg(monitorName)[option]

  spacing: 6

  Repeater {
    model: WallpaperState.accents

    MiniButton {
      required property var modelData

      text: modelData.label
      active: row.current === modelData.id
      onClicked: WallpaperState.set(row.monitorName, row.option, modelData.id)
    }
  }
}
