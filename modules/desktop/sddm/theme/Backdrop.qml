import QtQuick
import QtQuick.Effects
import "style"

// The picture behind the window, blurred and dimmed like the lock screen.
// The picture is the one chosen under LOGIN SCREEN PICTURE in the Display window (the shell copies it to
// /var/lib/sddm-retro/background); without one it is your Stylix wallpaper, bundled as `background`.
Item {
  Rectangle {
    anchors.fill: parent
    color: Skin.bg
  }

  Image {
    id: chosen
    visible: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(parent.width, parent.height)
    source: "file:///var/lib/sddm-retro/background"
  }

  Image {
    id: stock
    visible: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(parent.width, parent.height)
    source: Qt.resolvedUrl("background")
  }

  readonly property bool useChosen: chosen.status === Image.Ready

  MultiEffect {
    anchors.fill: parent
    source: parent.useChosen ? chosen : stock
    visible: chosen.status === Image.Ready || stock.status === Image.Ready
    blurEnabled: true
    blur: 1.0
    blurMax: 48
    brightness: -0.3
    saturation: -0.15
  }

  Rectangle {
    anchors.fill: parent
    color: "#55000000"
  }
}
