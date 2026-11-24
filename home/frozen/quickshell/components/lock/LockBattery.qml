import QtQuick
import qs

// Battery in the corner of the lock window's title bar: a small drawn cell, the percentage and the time left.
// The numbers come from SystemStats (UPower). Nothing is shown on a machine without a battery.
Row {
  id: root

  visible: SystemStats.hasBattery
  spacing: 8

  // the title bar is light with dark text, so everything here uses the dark colour; low battery turns red
  readonly property color ink: SystemStats.battery <= 15 && !SystemStats.charging ? Theme.red : Theme.bg

  // the cell
  Item {
    anchors.verticalCenter: parent.verticalCenter
    width: 24
    height: 12

    Rectangle {
      width: 21
      height: 12
      color: "transparent"
      border.width: 2
      border.color: root.ink

      Rectangle {
        x: 2
        y: 2
        height: parent.height - 4
        width: (parent.width - 4) * Math.min(100, SystemStats.battery) / 100
        color: root.ink
      }
    }

    Rectangle {
      x: 21
      y: 3
      width: 3
      height: 6
      color: root.ink
    }
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: SystemStats.battery + "%" + (SystemStats.charging ? " +" : "")
    color: root.ink
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: SystemStats.batteryTimeText.toUpperCase()
    color: root.ink
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 2
  }
}
