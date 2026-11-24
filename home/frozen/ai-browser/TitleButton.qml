import QtQuick

// The shell's title bar button: a dark outline on the light bar; filled with an orange symbol when active.
Rectangle {
  id: button

  property var c
  property string text: ""
  property bool active: false

  signal clicked

  width: 22
  height: 16
  radius: 3
  color: (active || mouse.containsMouse) ? c.bg : "transparent"
  border.color: c.bg
  border.width: c.border

  Text {
    anchors.centerIn: parent
    text: button.text
    color: button.active ? button.c.orange : (mouse.containsMouse ? button.c.fg : button.c.bg)
    font.family: button.c.fontMono
    font.bold: true
    font.pointSize: button.c.fontSize - 2
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: button.clicked()
  }
}
