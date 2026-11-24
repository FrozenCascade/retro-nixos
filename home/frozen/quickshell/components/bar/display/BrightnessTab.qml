import Quickshell
import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// The BRIGHTNESS tab: one card per monitor. A monitor that does not answer DDC/CI (or sits behind an HDMI
// splitter) is dimmed in software instead, and the tab says so.
Flickable {
  id: flick

  readonly property bool anySoft: Array.from(Quickshell.screens).some(s => DisplayState.kindOf(s.name) === "soft" && s.name !== Settings.laptopMonitor)

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 10

    SectionHead { width: parent.width; text: "MONITORS" }

    Repeater {
      model: Quickshell.screens

      delegate: BrightnessCard {
        required property var modelData
        width: col.width
        monitor: modelData
      }
    }

    Text {
      visible: flick.anySoft
      width: parent.width
      wrapMode: Text.WordWrap
      text: "SOFTWARE: THIS MONITOR DOES NOT ANSWER DDC/CI (A SPLITTER BLOCKS IT), SO THE PICTURE IS DARKENED INSTEAD OF THE BACKLIGHT."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }

    MiniButton {
      text: DisplayState.detecting ? "LOOKING..." : "DETECT DDC AGAIN"
      enabled: !DisplayState.detecting
      onClicked: DisplayState.detect()
    }
  }
}
