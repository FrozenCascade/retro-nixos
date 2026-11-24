import QtQuick
import qs

// One workspace button. No borders, the state is told by color alone:
//   the workspace you are on    light character on a gray chip
//   has windows                 light character
//   no windows                  gray character
//   left click: go there.  middle click: bring the focused window here.  scroll: step through workspaces.
Item {
  id: button

  required property string name         // "1" ... "6"
  property string current: ""           // the workspace this monitor is showing
  property var focusedWindow: null      // the window a middle click brings here

  // ---- look (edit here) ----
  readonly property real buttonSize: 26
  readonly property real fontSize: Theme.fontSize + 6
  readonly property color chipColor: Theme.fgDim
  readonly property color textOn: Theme.fg          // the workspace you are on, and ones with windows
  readonly property color textEmpty: Theme.fgDim    // ones without windows

  readonly property bool active: name === current
  readonly property bool occupied: Desktop.windowCount(name) > 0

  width: buttonSize
  height: buttonSize

  // the chip: only behind the workspace you are on
  Rectangle {
    anchors.fill: parent
    radius: Retro.corner
    color: button.active ? button.chipColor : "transparent"
  }

  Text {
    anchors.centerIn: parent
    text: Desktop.glyph(button.name)
    color: (button.active || button.occupied) ? button.textOn : button.textEmpty
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: button.fontSize
  }

  WorkspaceWheel {
    id: stepper
    workspace: button.current
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onWheel: wheel => stepper.handle(wheel)

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) {
        if (button.focusedWindow)
          Desktop.moveToWorkspace(button.focusedWindow, button.name);
      } else {
        Desktop.gotoWorkspace(button.name);
      }
    }
  }
}
