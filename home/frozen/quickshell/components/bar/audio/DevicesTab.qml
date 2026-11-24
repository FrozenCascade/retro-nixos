import QtQuick
import qs
import qs.components.bar.calendar

// The OUTPUT tab (playback devices) or the INPUT tab (recording devices), filtered by the search box.
Flickable {
  id: flick

  property string mode: "output"        // "output" or "input"
  property string query: ""

  readonly property var list: (mode === "output" ? AudioState.sinks : AudioState.sources).filter(n => query === "" || AudioState.label(n).toLowerCase().indexOf(query) !== -1)

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 10

    SectionHead { width: parent.width; text: flick.mode === "output" ? "PLAYBACK DEVICES" : "RECORDING DEVICES" }

    Text {
      visible: flick.list.length === 0
      text: flick.query === "" ? "NO DEVICES" : "NO MATCHES"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Repeater {
      model: flick.list
      delegate: DeviceCard {
        required property var modelData
        width: col.width
        node: modelData
        showTest: flick.mode === "input" && AudioState.isDefault(modelData)
      }
    }
  }
}
