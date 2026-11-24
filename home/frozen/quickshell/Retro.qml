pragma Singleton
import QtQuick
import Quickshell

Singleton {
  readonly property real corner: 3              // near-square corners
  readonly property real shadowOffset: 4        // hard drop shadow, no blur
  readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.6)
  readonly property color inset: Qt.rgba(0, 0, 0, 0.35)
  readonly property real borderWidth: 2          // frame and button outlines
  readonly property real titleHeight: 24         // popup title bar
}
