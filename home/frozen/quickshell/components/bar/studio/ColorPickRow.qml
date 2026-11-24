import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// The color picker of the CAPTURE tab. PICK lets you click any pixel on screen (hyprpicker, Escape cancels);
// the color goes to the clipboard as a hex code. The last few picks stay as small squares, and clicking one
// (or the hex code) copies it again. The list lives as long as the shell does.
Item {
  id: root

  // ---- edit here ----
  readonly property int maxHistory: 6       // picks kept, the newest one included

  property var history: []                  // hex codes, newest first
  property string note: ""                  // "COPIED" for a moment
  readonly property string current: history.length > 0 ? history[0] : ""

  height: 30     // the width comes from the anchors in CaptureTab.qml

  // puts a color first in the list (an old pick moves up instead of appearing twice)
  function remember(hex) {
    history = [hex].concat(history.filter(h => h !== hex)).slice(0, maxHistory);
  }

  function flash() {
    note = "COPIED";
    noteTimer.restart();
  }

  function copy(hex) {
    Quickshell.execDetached(["wl-copy", hex]);
    remember(hex);
    flash();
  }

  // --autocopy puts the code on the clipboard; the output is read here only to fill the list
  Process {
    id: picker
    command: ["hyprpicker", "--autocopy", "--format=hex"]
    stdout: StdioCollector {
      onStreamFinished: {
        const hex = text.trim().toUpperCase();
        if (/^#[0-9A-F]{6}$/.test(hex)) {     // empty when you cancel
          root.remember(hex);
          root.flash();
        }
      }
    }
  }

  Timer {
    id: noteTimer
    interval: 1500
    onTriggered: root.note = ""
  }

  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    MiniButton {
      anchors.verticalCenter: parent.verticalCenter
      height: 28
      padX: 18
      text: picker.running ? "PICKING..." : "PICK"
      enabled: !picker.running
      onClicked: picker.running = true
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 30
      height: 26
      radius: Retro.corner
      color: root.current !== "" ? root.current : Retro.inset
      border.width: Retro.borderWidth
      border.color: Theme.fgDim
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 84
      elide: Text.ElideRight
      text: root.note !== "" ? root.note : (root.current !== "" ? root.current : "NO PICK YET")
      color: root.note !== "" ? Theme.green : Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1

      MouseArea {
        anchors.fill: parent
        enabled: root.current !== ""
        onClicked: root.copy(root.current)
      }
    }

    // older picks, newest first
    Repeater {
      model: root.history.slice(1)

      Rectangle {
        required property var modelData

        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: Retro.corner
        color: modelData
        border.width: Retro.borderWidth
        border.color: Theme.fgDim

        MouseArea {
          anchors.fill: parent
          onClicked: root.copy(modelData)
        }
      }
    }
  }
}
