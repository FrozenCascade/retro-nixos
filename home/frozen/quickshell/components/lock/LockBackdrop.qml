import QtQuick
import QtQuick.Effects
import qs

// The picture behind the lock window. It is the picture chosen for the lock screen in the Display
// window (WALLPAPER tab), or else this monitor's own wallpaper, or else the theme's. Blurred and dimmed
// so the window and the clock stay readable.
Item {
  id: root

  property string screenName: ""

  readonly property var cfg: WallpaperState.cfg("")
  readonly property string path: cfg.lockImage !== "" ? cfg.lockImage : WallpaperState.imageOf(screenName)

  Rectangle {
    anchors.fill: parent
    color: Theme.bg
  }

  Image {
    id: picture
    anchors.fill: parent
    visible: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(root.width, root.height)
    source: root.path !== "" ? "file://" + root.path : ""
  }

  MultiEffect {
    anchors.fill: parent
    source: picture
    visible: picture.status === Image.Ready
    blurEnabled: root.cfg.lockBlur
    blur: 1.0
    blurMax: 48                 // lower is cheaper
    brightness: -0.3
    saturation: -0.15
  }

  Rectangle {
    anchors.fill: parent
    color: "#55000000"
  }
}
