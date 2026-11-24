import QtQuick
import qs
import "../../lib/nav.js" as Nav

// Small retro button for popup title bars (dark outline on the light title bar).
Rectangle {
  id: button

  property string text: ""
  property bool active: false        // e.g. pinned: drawn filled, with an orange symbol
  signal clicked

  // keyboard: Tab / arrows move between controls, Enter or Space presses
  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (Nav.isPress(event)) {
      button.clicked();
      event.accepted = true;
    } else if (Nav.move(button, event)) {
      event.accepted = true;
    }
  }
  onActiveFocusChanged: {
    if (activeFocus)
      Nav.reveal(button);
  }

  width: 22
  height: 16
  radius: 3
  color: (active || mouse.containsMouse) ? Theme.bg : "transparent"
  border.color: activeFocus ? Theme.orange : Theme.bg
  border.width: Retro.borderWidth

  Text {
    anchors.centerIn: parent
    text: button.text
    color: button.active ? Theme.orange : (mouse.containsMouse ? Theme.fg : Theme.bg)
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: button.clicked()
  }
}
