import QtQuick
import qs

// The thin vertical line between groups of bar items. The padding on each side is adjustable
// (the buttons already include their own 2 px shadow, so some spots want uneven padding).
Item {
  id: sep

  property real padLeft: 3.5
  property real padRight: 3.5
  property real lineHeight: 18

  width: padLeft + 2 + padRight
  height: 22

  Rectangle {
    x: sep.padLeft
    anchors.verticalCenter: parent.verticalCenter
    width: 2
    height: sep.lineHeight
    color: Theme.fgDim
  }
}
