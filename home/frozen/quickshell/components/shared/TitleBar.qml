import QtQuick
import qs

// Retro title bar: a light bar across the top of a framed window, "\\\ TITLE" on the left,
// optional [+] pin and [x] close buttons on the right. It sits inside the frame's border.
// Override `color` or `height` where a window needs something different.
Rectangle {
  id: bar

  property string title: ""
  property bool showPin: false
  property bool pinned: false
  property bool showClose: true
  property real leftPad: 10

  signal pinClicked
  signal closeClicked

  x: Retro.borderWidth
  y: Retro.borderWidth
  width: parent ? parent.width - Retro.borderWidth * 2 : 0
  height: Retro.titleHeight
  color: Theme.fg

  Text {
    anchors {
      left: parent.left
      right: buttons.left
      verticalCenter: parent.verticalCenter
      leftMargin: bar.leftPad
      rightMargin: 6
    }
    elide: Text.ElideRight
    text: "\\\\\\ " + bar.title.toUpperCase()
    color: Theme.bg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Row {
    id: buttons
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
      rightMargin: 6
    }
    spacing: 4

    TitleButton {
      visible: bar.showPin
      text: "+"
      active: bar.pinned
      onClicked: bar.pinClicked()
    }

    TitleButton {
      visible: bar.showClose
      text: "x"
      onClicked: bar.closeClicked()
    }
  }
}
