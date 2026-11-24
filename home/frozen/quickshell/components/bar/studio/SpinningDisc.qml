import QtQuick
import QtQuick.Shapes
import qs

// A disc that turns clockwise while `spinning` and holds still, at the angle it stopped at, when it is
// paused. It is drawn once and the graphics card only rotates the picture of it, so it costs almost
// nothing; `alive` (false while the tab is hidden) and a pause stop even the per-frame update.
//   kind     "dvd" (a sheen that shows the turning) or "vinyl" (dark, with grooves and a label)
//   seconds  time for one full turn
Item {
  id: disc

  property bool spinning: false
  property bool alive: true
  property string kind: "dvd"
  property real seconds: 5

  width: 190
  height: 190

  // The angle is advanced by hand, one frame at a time, so a change of speed applies at once and a pause
  // keeps the angle (an animation object fixes its duration when it starts).
  property real angle: 0

  FrameAnimation {
    running: disc.alive && disc.spinning
    onTriggered: disc.angle = (disc.angle + frameTime * 360 / Math.max(0.5, disc.seconds)) % 360
  }

  Item {
    id: face
    anchors.fill: parent
    rotation: disc.angle

    // drawn into a texture (with smoothing) and turned as a whole
    layer.enabled: true
    layer.smooth: true
    layer.samples: 4

    // ---- DVD: a silver sheen that wraps once around the disc ----
    Shape {
      anchors.fill: parent
      visible: disc.kind === "dvd"

      ShapePath {
        strokeWidth: -1
        fillGradient: ConicalGradient {
          centerX: disc.width / 2
          centerY: disc.height / 2
          angle: 0
          GradientStop { position: 0.00; color: Theme.fg }
          GradientStop { position: 0.12; color: Theme.fgDim }
          GradientStop { position: 0.25; color: Qt.darker(Theme.aqua, 1.5) }
          GradientStop { position: 0.37; color: Theme.bgSel }
          GradientStop { position: 0.50; color: Theme.fg }
          GradientStop { position: 0.62; color: Theme.fgDim }
          GradientStop { position: 0.75; color: Qt.darker(Theme.yellow, 1.7) }
          GradientStop { position: 0.87; color: Theme.bgSel }
          GradientStop { position: 1.00; color: Theme.fg }
        }
        PathAngleArc {
          centerX: disc.width / 2
          centerY: disc.height / 2
          radiusX: disc.width / 2
          radiusY: disc.height / 2
          startAngle: 0
          sweepAngle: 360
        }
      }
    }

    // ---- vinyl: near black, with two soft highlights opposite each other ----
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      visible: disc.kind === "vinyl"
      color: Qt.darker(Theme.bg, 1.6)
    }

    Shape {
      anchors.fill: parent
      visible: disc.kind === "vinyl"

      ShapePath {
        strokeWidth: -1
        fillGradient: ConicalGradient {
          centerX: disc.width / 2
          centerY: disc.height / 2
          angle: 0
          GradientStop { position: 0.00; color: "transparent" }
          GradientStop { position: 0.04; color: Qt.rgba(1, 1, 1, 0.16) }
          GradientStop { position: 0.10; color: "transparent" }
          GradientStop { position: 0.50; color: "transparent" }
          GradientStop { position: 0.54; color: Qt.rgba(1, 1, 1, 0.16) }
          GradientStop { position: 0.60; color: "transparent" }
          GradientStop { position: 1.00; color: "transparent" }
        }
        PathAngleArc {
          centerX: disc.width / 2
          centerY: disc.height / 2
          radiusX: disc.width / 2
          radiusY: disc.height / 2
          startAngle: 0
          sweepAngle: 360
        }
      }
    }

    // ---- rings: where the data (or grooves) begin and end ----
    Repeater {
      model: disc.kind === "vinyl" ? [0.96, 0.89, 0.82, 0.75, 0.68, 0.61, 0.54, 0.47] : [0.97, 0.66, 0.44]

      Rectangle {
        required property real modelData

        anchors.centerIn: parent
        width: disc.width * modelData
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, disc.kind === "vinyl" ? 0.5 : 0.3)
      }
    }

    // the clear hub of a DVD, or the label of a record
    Rectangle {
      anchors.centerIn: parent
      width: disc.width * (disc.kind === "vinyl" ? 0.34 : 0.32)
      height: width
      radius: width / 2
      color: disc.kind === "vinyl" ? Theme.orange : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.55)
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.35)
    }

    // the spindle hole shows what is behind the disc
    Rectangle {
      anchors.centerIn: parent
      width: disc.width * 0.1
      height: width
      radius: width / 2
      color: Theme.bg
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.5)
    }
  }
}
