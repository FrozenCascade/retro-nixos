import QtQuick
import qs
import qs.components.bar.calendar

// The right end of the bar: the tool buttons (studio, audio ... AI, session) and the clock.
// The Studio song key is the stretchy part: it takes the width needed for this group to be `fillWidth`
// wide, which keeps the window title (stretched between the workspace buttons and this group) centered
// on the screen. MonitorBar works out fillWidth.
Row {
  id: root

  required property var popups          // PopupController
  property real fillWidth: 0
  readonly property real minStudioWidth: 130

  // widths of everything but the song key, with the gaps between the three items
  readonly property real otherWidth: tools.fixedWidth + gap.width + clock.width + 2 * spacing

  spacing: 4

  ToolSection {
    id: tools
    anchors.verticalCenter: parent.verticalCenter
    studioWidth: Math.max(root.minStudioWidth, root.fillWidth - root.otherWidth)
    openName: root.popups.rightPopup
    pinned: root.popups.rightPinned
    held: root.popups.held
    onToggle: name => root.popups.toggle(name)
    onCloseRequested: name => root.popups.close(name)
    onPinToggled: root.popups.rightPinned = !root.popups.rightPinned
  }

  // extra space on the right, toward the clock
  BarSep {
    id: gap
    anchors.verticalCenter: parent.verticalCenter
    padLeft: 4
    padRight: 4
  }

  CalendarButton {
    id: clock
    anchors.verticalCenter: parent.verticalCenter
    open: root.popups.isOpen("calendar")
    onClicked: root.popups.toggle("calendar")
  }
}
