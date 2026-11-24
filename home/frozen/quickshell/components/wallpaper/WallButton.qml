import QtQuick
import qs

// A small raised key for the music wallpaper (previous, play/pause, next). Same look as the bar's keys.
Rectangle {
  id: key

  property string glyph: ""
  signal clicked

  width: 44
  height: 36
  radius: Retro.corner
  color: mouse.pressed ? Retro.inset : Theme.bgAlt
  border.width: Retro.borderWidth
  border.color: mouse.containsMouse && enabled ? Theme.orange : Theme.fg
  opacity: enabled ? 1 : 0.4

  Text {
    anchors.centerIn: parent
    text: key.glyph
    color: Theme.fg
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize + 3
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: key.clicked()
  }
}
