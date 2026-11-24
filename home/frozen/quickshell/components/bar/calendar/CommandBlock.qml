import Quickshell
import QtQuick
import qs

// A few lines of shell. Click the box to copy them.
Item {
  id: block

  property string title: ""
  property var lines: []
  property bool copied: false

  implicitHeight: head.height + 4 + box.height
  height: implicitHeight

  Text {
    id: head
    height: 18
    text: block.title
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Text {
    anchors.right: parent.right
    text: block.copied ? "COPIED" : (mouse.containsMouse ? "CLICK TO COPY" : "")
    color: Theme.orange
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  Rectangle {
    id: box
    y: head.height + 4
    width: parent.width
    height: body.implicitHeight + 16
    radius: Retro.corner
    color: Retro.inset
    border.width: Retro.borderWidth
    border.color: block.copied ? Theme.orange : (mouse.containsMouse ? Theme.fg : Theme.fgDim)

    Text {
      id: body
      x: 10
      y: 8
      width: parent.width - 20
      text: block.lines.join("\n")
      wrapMode: Text.WrapAnywhere
      color: Theme.fg
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 1
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | "$2"', "sh", block.lines.join("\n"), Tools.wlCopy]);
        block.copied = true;
        reset.restart();
      }
    }
  }

  Timer {
    id: reset
    interval: 1200
    onTriggered: block.copied = false
  }
}
