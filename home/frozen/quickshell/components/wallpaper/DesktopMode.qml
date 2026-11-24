import QtQuick
import qs

// DESKTOP: a clean background you can drag a selection box over, like a file manager's desktop.
// The box is see-through in the chosen theme colour and fades away when you let go.
Item {
  id: root

  property string monitorName: ""

  readonly property color accent: WallpaperState.accentColor(WallpaperState.cfg(monitorName).selectColor)

  // ---- edit here ----
  readonly property real fillAlpha: 0.22
  readonly property int fadeMs: 260

  MouseArea {
    id: area
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton

    property real startX: 0
    property real startY: 0

    onPressed: mouse => {
      fade.stop();
      startX = mouse.x;
      startY = mouse.y;
      box.x = mouse.x;
      box.y = mouse.y;
      box.width = 0;
      box.height = 0;
      box.opacity = 1;
    }

    onPositionChanged: mouse => {
      if (!pressed)
        return;
      const x = Math.max(0, Math.min(width, mouse.x));
      const y = Math.max(0, Math.min(height, mouse.y));
      box.x = Math.min(startX, x);
      box.y = Math.min(startY, y);
      box.width = Math.abs(x - startX);
      box.height = Math.abs(y - startY);
    }

    onReleased: fade.restart()
  }

  Rectangle {
    id: box
    visible: opacity > 0.01
    opacity: 0
    radius: 2
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.fillAlpha)
    border.width: 2
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.9)
  }

  NumberAnimation {
    id: fade
    target: box
    property: "opacity"
    to: 0
    duration: root.fadeMs
    easing.type: Easing.OutQuad
  }
}
