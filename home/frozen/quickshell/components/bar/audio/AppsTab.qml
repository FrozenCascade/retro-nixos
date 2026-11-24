import QtQuick
import qs
import qs.components.bar.calendar

// Applications that are playing or recording, filtered by the search box.
Flickable {
  id: flick

  property string query: ""

  readonly property var playing: AudioState.playRows.filter(r => query === "" || r.name.toLowerCase().indexOf(query) !== -1)
  readonly property var recording: AudioState.recRows.filter(r => query === "" || r.name.toLowerCase().indexOf(query) !== -1)

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 8

    SectionHead { width: parent.width; text: "PLAYING" }

    Text {
      visible: flick.playing.length === 0
      text: flick.query === "" ? "NOTHING IS PLAYING" : "NO MATCHES"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Repeater {
      model: flick.playing
      delegate: AppRow {
        required property var modelData
        width: col.width
        entry: modelData
      }
    }

    SectionHead { width: parent.width; text: "RECORDING" }

    Text {
      visible: flick.recording.length === 0
      text: flick.query === "" ? "NOTHING IS RECORDING" : "NO MATCHES"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Repeater {
      model: flick.recording
      delegate: AppRow {
        required property var modelData
        width: col.width
        entry: modelData
      }
    }
  }
}
