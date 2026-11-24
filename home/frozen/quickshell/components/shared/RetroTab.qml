import QtQuick
import qs
import "../../lib/nav.js" as Nav

// A tab: raised when idle, pressed in (with an orange label) when selected.
Item {
  id: tab

  property string label: ""
  property bool selected: false
  signal clicked

  // keyboard: Tab / arrows move between controls, Enter or Space presses
  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (Nav.isPress(event)) {
      tab.clicked();
      event.accepted = true;
    } else if (Nav.move(tab, event)) {
      event.accepted = true;
    }
  }
  onActiveFocusChanged: {
    if (activeFocus)
      Nav.reveal(tab);
  }

  height: 30

  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: Retro.shadowColor
    visible: !tab.selected
  }

  Rectangle {
    anchors.fill: parent
    radius: Retro.corner
    color: tab.selected ? Theme.bgSel : Theme.bgAlt

    Text {
      anchors.centerIn: parent
      text: tab.label
      color: tab.selected ? Theme.orange : Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }

  // keyboard focus ring
  Rectangle {
    anchors.fill: parent
    anchors.margins: -2
    radius: Retro.corner + 1
    color: "transparent"
    border.width: 2
    border.color: Theme.yellow
    visible: tab.activeFocus
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: tab.clicked()
  }
}
