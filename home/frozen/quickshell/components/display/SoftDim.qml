import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// Software dimming for monitors that cannot be dimmed any other way (no DDC/CI, for example behind an
// HDMI splitter): a see-through black layer over the whole screen, above every window. It ignores the
// mouse, and it only exists while a monitor actually needs it. Levels are set in DisplayState.
Scope {
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: layer

      required property var modelData
      readonly property real level: DisplayState.levelOf(modelData.name)

      screen: modelData
      visible: DisplayState.kindOf(modelData.name) === "soft" && level < 0.995
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      exclusionMode: ExclusionMode.Ignore
      color: Qt.rgba(0, 0, 0, 1 - level)
      mask: Region {}

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "qs-softdim"
    }
  }
}
