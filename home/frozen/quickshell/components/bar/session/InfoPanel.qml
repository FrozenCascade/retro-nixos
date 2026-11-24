import QtQuick
import qs

// "About this system": the distro logo and a short list of facts, like a small fastfetch.
Rectangle {
  id: panel

  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  Image {
    id: logo
    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
    width: 84
    height: 84
    sourceSize: Qt.size(168, 168)
    fillMode: Image.PreserveAspectFit
    source: Tools.distroLogo ? "file://" + Tools.distroLogo : ""
  }

  // shown when the logo file is not there
  Text {
    anchors.centerIn: logo
    visible: logo.status !== Image.Ready
    text: "NixOS"
    color: Theme.blue
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize + 8
  }

  Text {
    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 108 }
    text: (SessionState.facts.os || "LINUX").toUpperCase()
    color: Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize + 4
  }

  Text {
    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 134 }
    width: parent.width - 24
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: SessionState.facts.version || ""
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Text {
    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 154 }
    text: SessionState.user + "@" + SessionState.host
    color: Theme.yellow
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Rectangle {
    x: 12
    y: 182
    width: parent.width - 24
    height: 2
    color: Theme.fgDim
  }

  Flickable {
    id: list
    x: 12
    y: 192
    width: parent.width - 24
    height: parent.height - 192 - 8
    clip: true
    contentWidth: width
    contentHeight: rows.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: rows
      width: list.width
      spacing: 2

      Repeater {
        model: SessionState.infoRows
        delegate: Item {
          required property var modelData
          width: rows.width
          height: 22

          Text {
            width: 86
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.k
            color: Theme.orange
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 2
          }

          Text {
            x: 90
            width: parent.width - 90
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: modelData.v
            color: Theme.fg
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 2
          }
        }
      }
    }
  }
}
