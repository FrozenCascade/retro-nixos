import Quickshell
import QtQuick
import qs
import qs.components.shared

// The quick-tools button in the top bar: [clipboard] | [caps lock]
// The caps lock symbol lights up orange while caps lock is on.
Item {
  id: button

  property bool open: false
  signal clicked
  signal middleClicked

  readonly property real padX: 9
  readonly property bool caps: KeyboardState.capsLock

  // Looks for a symbolic icon in your icon theme: the first name that exists wins.
  function firstIcon(names) {
    for (const n of names) {
      const p = Quickshell.iconPath(n, true);
      if (p)
        return p;
    }
    return "";    // none found: the button falls back to a glyph
  }

  readonly property string clipboardIcon: firstIcon(["edit-paste-symbolic", "edit-paste", "clipboard-symbolic", "clipboard"])
  readonly property string capsIcon: firstIcon(["caps-lock-symbolic", "capslock-symbolic", "input-caps-on-symbolic", "input-caps-on", "caps-on", "caps-lock", "capslock"])

  width: padX * 2 + 7 + 18
  height: 22

  KeyFace {
    anchors.fill: parent
    down: button.open
  }

  Row {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    spacing: 7

    // caps lock: a lit orange chip while on, a dim symbol while off
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 26
      height: 18
      radius: Retro.corner
      color: button.caps ? Theme.orange : "transparent"

      Item {
        anchors.centerIn: parent
        width: 14
        height: 14
        opacity: button.caps ? 1.0 : 0.45

        Image {
          id: capsImage
          anchors.fill: parent
          sourceSize.width: 28
          sourceSize.height: 28
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          source: button.capsIcon
          visible: source !== ""
        }

        // fallback: the caps lock symbol as a character
        Text {
          anchors.centerIn: parent
          visible: !capsImage.visible
          text: "⇪"
          color: button.caps ? Theme.bg : Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize
        }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton)
        button.middleClicked();
      else
        button.clicked();
    }
  }
}
