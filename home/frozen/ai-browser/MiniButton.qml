import QtQuick

// The shell's MiniButton: raised, pressed in (orange label) when active. `c` is the color table from main.qml.
Item {
  id: btn

  property var c
  property string text: ""
  property bool active: false
  property real padX: 8

  signal clicked

  implicitWidth: Math.max(24, label.implicitWidth + padX * 2)
  implicitHeight: 22
  width: implicitWidth
  height: implicitHeight
  opacity: enabled ? 1 : 0.4

  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: btn.c.corner
    color: btn.c.shadowColor
    visible: !btn.active && !mouse.pressed
  }

  Rectangle {
    x: mouse.pressed ? 2 : 0
    y: mouse.pressed ? 2 : 0
    width: parent.width
    height: parent.height
    radius: btn.c.corner
    color: btn.active || mouse.containsMouse ? btn.c.bgSel : btn.c.bgAlt

    Text {
      id: label
      anchors.centerIn: parent
      width: Math.min(implicitWidth, parent.width - btn.padX * 2)
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
      text: btn.text
      color: btn.active ? btn.c.orange : btn.c.fg
      font.family: btn.c.fontMono
      font.bold: true
      font.pointSize: btn.c.fontSize - 1
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
