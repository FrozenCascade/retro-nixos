import QtQuick
import qs

// Audio bars from cava, filling this item: the bars grow upward from its bottom edge.
// Counts itself as a user of the cava feed while shown, so cava runs only when a bar display is on screen.
Item {
  id: root

  property color barColor: Theme.orange
  property real gap: 3
  property real minHeight: 2            // a quiet bar is still a thin line

  // counted only while visible, so a hidden display does not keep cava running
  property bool counted: false

  function sync() {
    if (visible && !counted) {
      WallpaperState.cavaUsers++;
      counted = true;
    } else if (!visible && counted) {
      WallpaperState.cavaUsers--;
      counted = false;
    }
  }

  onVisibleChanged: sync()
  Component.onCompleted: sync()
  Component.onDestruction: {
    if (counted)
      WallpaperState.cavaUsers--;
  }

  Repeater {
    model: WallpaperState.cavaBars

    Rectangle {
      required property int index

      readonly property real level: Math.min(1, WallpaperState.bars[index] || 0)

      x: index * (root.width / WallpaperState.cavaBars) + root.gap / 2
      width: root.width / WallpaperState.cavaBars - root.gap
      height: Math.max(root.minHeight, level * root.height)
      y: root.height - height
      color: root.barColor
    }
  }
}
