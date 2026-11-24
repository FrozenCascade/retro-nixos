import QtQuick
import "style"

// Battery for the title bar. The greeter cannot ask the system for the battery, so a small systemd job
// (sddm.nix) writes /run/sddm-battery/Battery.qml every 30 seconds and this loads it. The ?t= part makes
// QML read the file again instead of reusing the copy it already has. If the number ever stops
// changing, that is the one thing to look at.
Item {
  id: root

  property int stamp: 0
  readonly property var info: loader.item
  readonly property bool shown: info !== null && info.present

  implicitWidth: row.implicitWidth
  implicitHeight: 14
  visible: shown

  Loader {
    id: loader
    source: "file:///run/sddm-battery/Battery.qml?t=" + root.stamp
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.stamp += 1
  }

  function duration(secs) {
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    return h > 0 ? h + "H " + (m < 10 ? "0" : "") + m + "M" : m + "M";
  }

  readonly property bool charging: shown && info.status === "Charging"
  readonly property string timeText: {
    if (!shown)
      return "";
    if (info.status === "Full")
      return "FULL";
    if (info.seconds <= 0)
      return "";
    return duration(info.seconds) + (charging ? " TO FULL" : " LEFT");
  }
  readonly property color ink: shown && info.percent <= 15 && !charging ? Skin.red : Skin.bg

  Row {
    id: row
    spacing: 8

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
          width: (parent.width - 4) * (root.shown ? Math.min(100, root.info.percent) : 0) / 100
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
      text: root.shown ? root.info.percent + "%" + (root.charging ? " +" : "") : ""
      color: root.ink
      font.family: Skin.fontMono
      font.bold: true
      font.pointSize: Skin.fontSize - 2
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.timeText
      color: root.ink
      font.family: Skin.fontMono
      font.pointSize: Skin.fontSize - 2
    }
  }
}
