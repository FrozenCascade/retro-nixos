import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// The laptop screen switched off: a black cover over it, with a very dim notice that fades in and out
// now and then. A click or a touch brings the screen back; moving the pointer over it does not.
// Switch it from the Display button (middle click), the Display window, or:  qs ipc call display toggleLaptop
Scope {
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: cover

      required property var modelData

      screen: modelData
      visible: modelData.name === Settings.laptopMonitor && DisplayState.laptopHidden
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      exclusionMode: ExclusionMode.Ignore
      color: "black"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "qs-laptop-blank"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Text {
        id: notice
        anchors.centerIn: parent
        text: "DISPLAY DISABLED"
        color: Theme.fgDim
        opacity: 0
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize

        // mostly invisible: a slow, faint appearance every half minute
        SequentialAnimation on opacity {
          running: cover.visible
          loops: Animation.Infinite

          PauseAnimation { duration: 25000 }
          NumberAnimation { to: 0.25; duration: 2500 }
          PauseAnimation { duration: 3000 }
          NumberAnimation { to: 0; duration: 2500 }
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: DisplayState.setLaptopHidden(false)
      }
    }
  }
}
