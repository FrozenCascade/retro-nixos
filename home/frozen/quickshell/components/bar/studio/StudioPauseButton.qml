import QtQuick
import qs
import qs.components.shared

// The thin play/pause key next to the song button; it shows the state (pause symbol while playing).
//   click: play/pause   middle click: mute the player   wheel: forward / back
Item {
  id: button

  property bool playing: false
  property bool muted: false         // dims through the built-in `enabled` when there is no player

  signal clicked
  signal middleClicked
  signal scrolled(int dir)

  width: 28
  height: 22

  KeyFace {
    id: face
    width: button.width - 2
    height: 22
    down: button.playing
    lit: mouse.hot
  }

  Text {
    anchors.centerIn: face
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    text: button.playing ? Glyphs.pause : Glyphs.play
    color: !button.enabled ? Theme.fgDim : (button.muted ? Theme.red : (button.playing ? Theme.orange : Theme.fg))
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize + 1
  }

  MouseArea {
    id: mouse
    anchors.fill: face
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    property real acc: 0

    property bool hot: false
    onEntered: hot = true
    onExited: hot = false
    onPositionChanged: hot = true

    onClicked: mouse => {
      hot = false;
      if (mouse.button === Qt.MiddleButton)
        button.middleClicked();
      else
        button.clicked();
    }

    onWheel: wheel => {
      wheel.accepted = true;
      acc += wheel.angleDelta.y;
      while (Math.abs(acc) >= 120) {
        button.scrolled(acc > 0 ? 1 : -1);
        acc -= acc > 0 ? 120 : -120;
      }
    }
  }
}
