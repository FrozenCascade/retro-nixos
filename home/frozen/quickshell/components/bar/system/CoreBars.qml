import QtQuick
import qs

// Bar graph: one bar per CPU core (0-100%), in the same LCD-style box.
Item {
  id: bars

  property var values: []              // percent per core
  readonly property int count: values ? values.length : 0

  implicitHeight: 118                  // the box (100) plus the labels

  Rectangle {
    id: box
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
    height: 100
    radius: 3
    color: Qt.rgba(0, 0, 0, 0.35)
    border.color: Theme.fgDim
    border.width: Retro.borderWidth

    // faint grid
    Repeater {
      model: 3

      Rectangle {
        required property int index
        x: 2
        y: 2 + (box.height - 4) * (index + 1) / 4
        width: box.width - 4
        height: 1
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)
      }
    }

    Row {
      id: row
      anchors.fill: parent
      anchors.margins: 6
      spacing: 3

      Repeater {
        model: bars.count

        Item {
          id: slot
          required property int index
          readonly property real value: bars.values[index] || 0

          width: bars.count > 0 ? (row.width - row.spacing * (bars.count - 1)) / bars.count : 0
          height: row.height

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(2, parent.height * slot.value / 100)
            radius: 1

            // busier cores turn orange, then red
            color: slot.value > 85 ? Theme.red : (slot.value > 60 ? Theme.orange : Theme.yellow)

            Behavior on height {
              NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }
    }
  }

  Text {
    anchors {
      left: parent.left
      top: box.bottom
      topMargin: 3
    }
    text: "CORE 1"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 3
  }

  Text {
    anchors {
      right: parent.right
      top: box.bottom
      topMargin: 3
    }
    text: "CORE " + bars.count
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 3
  }
}
