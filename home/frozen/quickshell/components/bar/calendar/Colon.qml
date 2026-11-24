import QtQuick
import qs

Text {
  property real size: Theme.fontSize

  anchors.verticalCenter: parent.verticalCenter
  text: ":"
  color: Theme.fg
  font.family: Theme.fontMono
  font.bold: true
  font.pointSize: size
}
