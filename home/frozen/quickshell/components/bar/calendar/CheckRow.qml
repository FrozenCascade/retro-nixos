import QtQuick
import qs
import "../../../lib/nav.js" as Nav

// A retro check box with a label. It only reports the click; the owner updates `checked`.
Item {
  id: row

  property bool checked: false
  property string label: ""
  signal toggled(bool value)

  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (Nav.isPress(event)) {
      row.toggled(!row.checked);
      event.accepted = true;
    } else if (Nav.move(row, event)) {
      event.accepted = true;
    }
  }
  onActiveFocusChanged: {
    if (activeFocus)
      Nav.reveal(row);
  }

  implicitHeight: 24
  height: implicitHeight
  implicitWidth: box.width + 10 + text.implicitWidth

  Rectangle {
    id: box
    anchors.verticalCenter: parent.verticalCenter
    width: 16
    height: 16
    radius: Retro.corner
    color: Retro.inset
    border.width: Retro.borderWidth
    border.color: row.activeFocus ? Theme.yellow : (mouse.containsMouse ? Theme.fg : Theme.fgDim)

    Rectangle {
      anchors.centerIn: parent
      width: 8
      height: 8
      color: Theme.orange
      visible: row.checked
    }
  }

  Text {
    id: text
    anchors { left: box.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
    text: row.label
    color: row.checked ? Theme.fg : Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.toggled(!row.checked)
  }
}
