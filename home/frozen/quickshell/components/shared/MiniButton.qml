import QtQuick
import qs
import "../../lib/nav.js" as Nav

// A small raised button with a glyph or a short label, for toolbars and list rows.
// `active` = pressed in with an orange label (a star that is on), `danger` = red label.
Item {
  id: btn

  property string text: ""
  property bool active: false
  property bool danger: false
  property real padX: 8
  signal clicked

  // keyboard: Tab / arrows move between controls, Enter or Space presses
  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (Nav.isPress(event)) {
      btn.clicked();
      event.accepted = true;
    } else if (Nav.move(btn, event)) {
      event.accepted = true;
    }
  }
  onActiveFocusChanged: {
    if (activeFocus)
      Nav.reveal(btn);
  }

  readonly property bool hovered: mouse.containsMouse

  implicitWidth: Math.max(24, label.implicitWidth + padX * 2)
  implicitHeight: 22
  width: implicitWidth
  height: implicitHeight

  // raised-button shadow: gone while pressed or active
  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: Retro.shadowColor
    visible: !btn.active && !mouse.pressed
  }

  Rectangle {
    x: mouse.pressed ? 2 : 0
    y: mouse.pressed ? 2 : 0
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: btn.active || mouse.containsMouse ? Theme.bgSel : Theme.bgAlt

    Text {
      id: label
      anchors.centerIn: parent
      width: Math.min(implicitWidth, parent.width - btn.padX * 2)
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
      text: btn.text
      color: btn.danger ? Theme.red : (btn.active ? Theme.orange : Theme.fg)
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
    visible: btn.activeFocus
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
