import QtQuick
import qs
import "../../../lib/calendar.js" as Cal

// One day in the week list. Months alternate between shaded and plain so you can see where one ends.
Rectangle {
  id: cell

  property int dn: 0
  property bool selected: false
  property bool today: false
  property int focusKey: 0            // year * 12 + month of the month in view

  signal picked
  signal opened

  readonly property var ymd: Cal.ymd(dn)
  readonly property bool inFocus: ymd.y * 12 + ymd.m === focusKey
  readonly property var flags: CalendarStore.dayFlags(dn)
  readonly property string moon: CalendarStore.settings.showMoon ? CalendarStore.moonGlyph(dn) : ""

  color: selected ? Theme.bgSel : (ymd.m % 2 === 0 ? Retro.inset : "transparent")
  border.width: today ? Retro.borderWidth : (mouse.containsMouse ? 1 : 0)
  border.color: today ? Theme.orange : Theme.fgDim

  Text {
    x: 5
    y: 3
    text: cell.ymd.d === 1 ? "1 " + Cal.MONTHS_SHORT[cell.ymd.m] : String(cell.ymd.d)
    color: cell.today ? Theme.orange : (cell.inFocus ? Theme.fg : Theme.fgDim)
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize
  }

  Text {
    anchors { right: parent.right; top: parent.top; rightMargin: 4; topMargin: 4 }
    visible: cell.moon !== ""
    text: cell.moon
    color: cell.flags.phase !== "" ? Theme.yellow : Theme.fgDim
    font.family: "Weather Icons"
    font.pointSize: Theme.fontSize - 1
  }

  Row {
    x: 5
    y: parent.height - 10
    spacing: 3
    Rectangle { visible: cell.flags.h > 0; width: 6; height: 6; color: Theme.green }
    Rectangle { visible: cell.flags.e > 0; width: 6; height: 6; color: Theme.blue }
    Rectangle { visible: cell.flags.r > 0; width: 6; height: 6; color: Theme.orange }
    Rectangle { visible: cell.flags.season; width: 6; height: 6; color: Theme.yellow; rotation: 45 }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: cell.picked()
    onDoubleClicked: cell.opened()
  }
}
