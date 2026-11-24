import QtQuick
import "style"

// A raised key with an icon above its label. `confirm`: the first click shows "SURE?" for three seconds,
// the second one runs it. Same behaviour as the Tile in the shell.
Item {
  id: key

  property string glyph: ""
  property string label: ""
  property bool confirm: false
  property color tint: Skin.fg
  property bool armed: false

  signal activated

  function press() {
    if (confirm && !armed) {
      armed = true;
      reset.restart();
    } else {
      armed = false;
      activated();
    }
  }

  Timer {
    id: reset
    interval: 3000
    onTriggered: key.armed = false
  }

  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: Skin.corner
    color: Skin.shadow
    visible: !mouse.pressed
  }

  Rectangle {
    x: mouse.pressed ? 2 : 0
    y: mouse.pressed ? 2 : 0
    width: parent.width
    height: parent.height
    radius: Skin.corner
    color: mouse.containsMouse ? Skin.bgSel : Skin.bgAlt
    border.width: key.armed ? Skin.borderWidth : 0
    border.color: Skin.red

    Text {
      anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
      text: key.glyph
      color: key.armed ? Skin.red : key.tint
      font.family: Skin.fontMono
      font.pointSize: Skin.fontSize + 6
    }

    Text {
      anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
      text: key.armed ? "SURE?" : key.label
      color: key.armed ? Skin.red : Skin.fg
      font.family: Skin.fontMono
      font.bold: true
      font.pointSize: Skin.fontSize - 3
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: key.press()
  }
}
