import QtQuick
import qs
import qs.components.shared

// A bar key in the style of the system button: raised, pressed in while its window is open.
// It shows one icon (which the owner changes with its state) and an optional small dot.
// The item is 2 px wider than the key itself, so the shadow is inside it and spacing around it is even.
Item {
  id: button

  property string glyph: ""
  property string iconSource: ""      // an image instead of the glyph (for example a logo from the icon theme)
  property color tint: Theme.fg
  property bool open: false
  property bool dot: false

  signal clicked
  signal middleClicked
  signal scrolled(int dir)            // +1 wheel up, -1 wheel down

  width: 36
  height: 22

  KeyFace {
    id: face
    width: 34
    height: 22
    down: button.open
    lit: mouse.hot
  }

  Image {
    anchors.centerIn: face
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    width: 16
    height: 16
    sourceSize.width: 32
    sourceSize.height: 32
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    source: button.iconSource
    visible: source !== ""
  }

  Text {
    anchors.centerIn: face
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    visible: button.iconSource === ""
    text: button.glyph
    color: button.tint
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize + 2
  }

  Rectangle {
    visible: button.dot
    anchors { right: face.right; top: face.top; rightMargin: 3; topMargin: 3 }
    width: 7
    height: 7
    radius: 4
    color: Theme.orange
  }

  MouseArea {
    id: mouse
    anchors.fill: face
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    property real acc: 0

    // Hover is cleared by a click and only returns when the pointer moves. Opening or closing a
    // window can swallow the "pointer left" event, which used to leave the key lit.
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
