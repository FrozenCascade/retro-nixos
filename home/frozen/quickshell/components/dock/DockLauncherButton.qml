import QtQuick
import qs

// The first button of the dock: opens the launcher. Scroll on it to change workspace (while holding another
// dock button: to move that app's windows instead). Middle click hides the dock.
Item {
  id: root

  required property var host                 // the Dock

  width: host.buttonSize
  height: host.buttonSize
  z: mouse.containsMouse ? 1 : 0

  // raised-button shadow (always visible)
  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: Retro.shadowColor
  }

  // button face
  Rectangle {
    anchors.fill: parent
    radius: Retro.corner
    color: Theme.bgAlt
  }

  Image {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 0 : -1

    width: root.host.iconSize
    height: root.host.iconSize

    sourceSize.width: root.host.iconSize * 2
    sourceSize.height: root.host.iconSize * 2

    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    source: root.host.launcherIcon()
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    property real wheelAccum: 0

    onEntered: {
      root.host.hoverItem = root;
      root.host.showDock();
    }

    onExited: {
      if (root.host.hoverItem === root)
        root.host.hoverItem = null;
    }

    onClicked: event => {
      if (event.button === Qt.MiddleButton)
        root.host.forceHideDock();
      else if (event.button === Qt.LeftButton)
        root.host.openLauncher();
    }

    onWheel: wheel => {
      wheel.accepted = true;

      // collect scroll until a full notch (touchpads send many small steps)
      wheelAccum += wheel.angleDelta.y;
      if (Math.abs(wheelAccum) < 120)
        return;
      const delta = wheelAccum > 0 ? -1 : 1;      // up = backward
      wheelAccum = 0;

      // holding a dock button while scrolling here sends that app's windows to the next / previous workspace
      if (root.host.dragTask)
        root.host.sendGroup(root.host.dragTask.group, delta);
      else
        root.host.switchWorkspace(delta);
    }
  }
}
