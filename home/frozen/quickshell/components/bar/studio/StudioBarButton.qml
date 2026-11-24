import QtQuick
import qs
import qs.components.shared

// The wide key in the bar that shows the current song. Raised, pressed in while the Studio window is open.
// The width is set by the bar so the window title in the middle stays centered on the screen.
// While recording, a red dot sits at the left and the text gives up room for it.
//   click: open the window   middle click: start / stop recording   wheel: the next or previous player
Item {
  id: button

  property bool open: false
  property bool hasPlayer: false
  property bool recording: false
  property string text: ""

  signal clicked
  signal middleClicked
  signal scrolled(int dir)            // +1 wheel up, -1 wheel down

  width: 160
  height: 22

  KeyFace {
    id: face
    width: button.width - 2
    height: 22
    down: button.open
    lit: mouse.hot
  }

  Row {
    id: row
    anchors.centerIn: face
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    spacing: 6

    // the recording dot: it blinks slowly
    Rectangle {
      id: dot
      anchors.verticalCenter: parent.verticalCenter
      visible: button.recording
      width: 10
      height: 10
      radius: 5
      color: Theme.red

      SequentialAnimation on opacity {
        running: button.recording
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 700 }
        NumberAnimation { to: 1.0; duration: 700 }
      }
    }

    Text {
      id: note
      anchors.verticalCenter: parent.verticalCenter
      text: Glyphs.music
      color: button.hasPlayer ? Theme.fg : Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize + 1
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      // what is left of the key after the dot, the note, the gaps and a little padding
      width: Math.min(implicitWidth, face.width - 20 - note.implicitWidth - (dot.visible ? dot.width + row.spacing : 0) - row.spacing)
      elide: Text.ElideRight
      text: button.text
      color: button.hasPlayer ? Theme.fg : Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: face
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    property real acc: 0

    // same hover handling as ToolButton: a click clears it, moving the pointer brings it back
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
