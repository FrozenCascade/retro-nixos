import Quickshell
import QtQuick
import qs
import qs.components.shared

// The pin button at the left end of the bar. Pinned: the bar always shows. Unpinned: autohide.
// Left click toggles. Middle click hides the bar until the pointer re-enters the top edge.
Item {
  id: button

  property bool pinned: true

  signal toggled
  signal hideRequested

  // The pin icon comes from your icon theme: the first name that exists wins. Put your favorite first.
  readonly property var iconNames: ["view-pin-symbolic", "pin-symbolic", "emblem-pinned-symbolic", "window-pin", "view-pin", "pin", "emblem-pinned"]

  function findIcon() {
    for (const n of iconNames) {
      const p = Quickshell.iconPath(n, true);
      if (p)
        return p;
    }
    return "";        // none found: the button falls back to a Nerd Font thumbtack
  }

  width: 26
  height: 22

  KeyFace {
    anchors.fill: parent
    down: button.pinned
  }

  // the symbol: tilted while unpinned
  Item {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    width: 16
    height: 16
    rotation: button.pinned ? 0 : 45
    opacity: button.pinned ? 1.0 : 0.75

    Behavior on rotation {
      NumberAnimation {
        duration: 120
      }
    }

    Image {
      id: pinImage
      anchors.fill: parent
      sourceSize.width: 32
      sourceSize.height: 32
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      source: button.findIcon()
      visible: source !== ""
    }

    Text {
      anchors.centerIn: parent
      visible: !pinImage.visible
      text: "\uf08d"
      color: button.pinned ? Theme.fg : Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton)
        button.hideRequested();
      else
        button.toggled();
    }
  }
}
