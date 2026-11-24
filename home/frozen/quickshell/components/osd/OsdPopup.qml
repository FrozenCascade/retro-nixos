import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs

// The small indicator at the bottom middle of the screen, like KDE's: an icon, a bar and a number.
// It is the shared body of the volume and brightness pop-ups (VolumeOsd, BrightnessOsd). Those two set
// what it shows and call poke() when it should appear; it fades after a moment, on the screen you are
// working on. Add anything that should be listened to as a child (a Connections or an IpcHandler).
Scope {
  id: root

  // ---- what it shows ----
  property string glyph: ""
  property color glyphTint: Theme.fg
  property real fraction: 0             // how full the bar is, 0..1
  property color fillColor: Theme.blue
  property string label: ""
  property color labelTint: Theme.fg
  property string namespace: "qs-osd"

  property bool shown: false
  property bool ready: false

  // ignore changes reported while the shell is starting
  Timer {
    interval: 3000
    running: true
    onTriggered: root.ready = true
  }

  Timer {
    id: hide
    interval: 1400
    onTriggered: root.shown = false
  }

  // appear for a moment (only once the shell has settled)
  function poke() {
    if (!ready)
      return;
    show();
  }

  // appear for a moment, always (for testing)
  function show() {
    shown = true;
    hide.restart();
  }

  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: osd

      required property var modelData

      // only on the screen you are working on
      readonly property bool here: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === modelData.name

      screen: modelData
      anchors.bottom: true
      margins.bottom: Math.round(modelData.height * 0.2)     // between the middle and the bottom
      implicitWidth: 340
      implicitHeight: 70
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      mask: Region {}
      visible: root.shown || card.opacity > 0.01

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: root.namespace

      Item {
        id: card
        anchors.centerIn: parent
        width: 320
        height: 56
        opacity: root.shown && osd.here ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: 160
          }
        }

        Rectangle {
          x: Retro.shadowOffset
          y: Retro.shadowOffset
          width: frame.width
          height: frame.height
          radius: Retro.corner
          color: Retro.shadowColor
        }

        Rectangle {
          id: frame
          width: card.width
          height: card.height
          radius: Retro.corner
          color: Theme.bg
          border.width: Retro.borderWidth
          border.color: Theme.fg

          Text {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.glyphTint
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize + 10
          }

          Rectangle {
            x: 62
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 62 - 76
            height: 10
            radius: 2
            color: Retro.inset
            border.width: 1
            border.color: Theme.fgDim

            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, root.fraction))
              height: parent.height
              radius: 2
              color: root.fillColor
            }
          }

          Text {
            anchors {
              right: parent.right
              rightMargin: 14
              verticalCenter: parent.verticalCenter
            }
            text: root.label
            color: root.labelTint
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize + 1
          }
        }
      }
    }
  }
}
