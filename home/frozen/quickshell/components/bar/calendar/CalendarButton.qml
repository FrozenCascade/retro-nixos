import QtQuick
import qs

// The clock in the top bar, "dd hh:mm:ss", drawn like the window title box. Click: the calendar.
// Middle click: switch between 24-hour and 12-hour time (remembered).
Rectangle {
  id: button

  property bool open: false
  // the title text is Theme.fontSize - 1; this is one step larger so the clock reads at a glance
  property real textSize: Theme.fontSize

  signal clicked

  readonly property string hour: CalendarStore.settings.clock12 ? Clock.hh12 : Clock.hh

  width: row.implicitWidth + 20
  height: 24
  radius: Retro.corner
  color: button.open ? Theme.bgSel : Retro.inset
  border.width: Retro.borderWidth
  border.color: button.open ? Theme.orange : (mouse.hot ? Theme.fg : Theme.fgDim)

  Row {
    id: row
    anchors.centerIn: parent

    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: Clock.dd.charAt(0) }
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: Clock.dd.charAt(1) }
    Item { width: 9; height: 1 }
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: button.hour.charAt(0) }
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: button.hour.charAt(1) }
    Colon {}
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: Clock.mm.charAt(0) }
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: Clock.mm.charAt(1) }
    Colon {}
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: Clock.ss.charAt(0) }
    TickDigit { anchors.verticalCenter: parent.verticalCenter; size: button.textSize; value: Clock.ss.charAt(1) }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    // Hover is cleared by a click and only comes back when the pointer moves, so the border
    // cannot stay white when the popup opening or closing swallows the "pointer left" event.
    property bool hot: false
    onEntered: hot = true
    onExited: hot = false
    onPositionChanged: hot = true

    onClicked: mouse => {
      hot = false;
      if (mouse.button === Qt.MiddleButton)
        CalendarStore.setSetting("clock12", !CalendarStore.settings.clock12);
      else
        button.clicked();
    }
  }
}
