import QtQuick
import qs

// "TITLE ------------" divider between groups
Item {
  property string text: ""

  height: 22

  Text {
    id: label
    anchors.verticalCenter: parent.verticalCenter
    text: parent.text
    color: Theme.yellow
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Rectangle {
    anchors { left: label.right; right: parent.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
    height: 2
    color: Theme.fgDim
  }
}
