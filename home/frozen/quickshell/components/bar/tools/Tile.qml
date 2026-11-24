import QtQuick
import qs
import "../../../lib/nav.js" as Nav

// A big raised key with an icon and a label, for toggles and power actions.
// `confirm`: the first click asks "SURE?" for three seconds, the second one does it.
Item {
  id: tile

  property string glyph: ""
  property string label: ""
  property string sub: ""               // small state text under the label
  property bool active: false           // pressed in, orange (a switch that is on)
  property bool confirm: false
  property bool compact: false          // icon above the label, for narrow tiles
  property color tint: Theme.fg
  property real labelSize: Theme.fontSize - 1

  property bool armed: false

  signal activated

  // keyboard: Tab / arrows move between controls, Enter or Space presses
  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (Nav.isPress(event)) {
      tile.press();
      event.accepted = true;
    } else if (Nav.move(tile, event)) {
      event.accepted = true;
    }
  }
  onActiveFocusChanged: {
    if (activeFocus)
      Nav.reveal(tile);
  }

  function press() {
    if (confirm && !armed) {
      armed = true;
      reset.restart();
    } else {
      armed = false;
      activated();
    }
  }

  implicitWidth: 100
  implicitHeight: compact ? 56 : 52
  width: implicitWidth
  height: implicitHeight

  Timer {
    id: reset
    interval: 3000
    onTriggered: tile.armed = false
  }

  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: Retro.shadowColor
    visible: !tile.active && !mouse.pressed
  }

  Rectangle {
    id: face
    x: mouse.pressed ? 2 : 0
    y: mouse.pressed ? 2 : 0
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: tile.active || mouse.containsMouse ? Theme.bgSel : Theme.bgAlt
    border.width: tile.armed || tile.activeFocus ? Retro.borderWidth : 0
    border.color: tile.armed ? Theme.red : Theme.yellow

    Text {
      id: icon
      x: tile.compact ? (parent.width - width) / 2 : 12
      y: tile.compact ? 8 : (parent.height - height) / 2
      text: tile.glyph
      color: tile.armed ? Theme.red : (tile.active ? Theme.orange : tile.tint)
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize + 6
    }

    Column {
      x: tile.compact ? 0 : 52
      y: tile.compact ? 36 : (parent.height - height) / 2
      width: tile.compact ? parent.width : parent.width - 58
      spacing: 1

      Text {
        width: parent.width
        horizontalAlignment: tile.compact ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
        text: tile.armed ? "SURE?" : tile.label
        color: tile.armed ? Theme.red : (tile.active ? Theme.orange : Theme.fg)
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: tile.labelSize
      }

      Text {
        visible: tile.sub !== "" && !tile.compact
        width: parent.width
        elide: Text.ElideRight
        text: tile.sub
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.press()
  }
}
