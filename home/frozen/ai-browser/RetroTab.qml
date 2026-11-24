import QtQuick

// The shell's RetroTab: raised when idle, pressed in (orange label) when selected.
Item {
  id: tab

  property var c
  property string label: ""
  property bool selected: false

  signal clicked
  signal middleClicked

  height: 30

  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: tab.c.corner
    color: tab.c.shadowColor
    visible: !tab.selected
  }

  Rectangle {
    anchors.fill: parent
    radius: tab.c.corner
    color: tab.selected ? tab.c.bgSel : tab.c.bgAlt

    Text {
      anchors.centerIn: parent
      text: tab.label
      color: tab.selected ? tab.c.orange : tab.c.fg
      font.family: tab.c.fontMono
      font.bold: true
      font.pointSize: tab.c.fontSize - 1
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => mouse.button === Qt.MiddleButton ? tab.middleClicked() : tab.clicked()
  }
}
