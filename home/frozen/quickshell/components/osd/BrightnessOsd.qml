import QtQuick
import Quickshell.Io
import qs

// The brightness indicator. It appears when the brightness is changed from the bar button or a key
// (DisplayState.poked), showing the monitor you are working on. The drawing is in OsdPopup.
OsdPopup {
  id: osd

  readonly property real level: DisplayState.currentLevel

  glyph: DisplayState.bulb(level)
  glyphTint: Theme.yellow
  fraction: level
  fillColor: Theme.yellow
  label: Math.round(level * 100) + "%"
  namespace: "qs-osd-brightness"

  // test it:  qs ipc call osd-brightness show
  IpcHandler {
    target: "osd-brightness"

    function show(): void {
      osd.show();
    }
  }

  Connections {
    target: DisplayState

    function onPoked() {
      osd.poke();
    }
  }
}
