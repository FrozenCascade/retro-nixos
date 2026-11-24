import QtQuick
import qs
import "../../../lib/calendar.js" as Cal

// The year view (twelve months) and the decade view (twelve years). Wheel or drag up and down
// to move a year (or a decade) at a time. Each cell counts what is in it.
Item {
  id: root

  property int mode: 1                // 1 = months of `year`, 2 = years from decadeStart - 1
  property int year: 2026
  property int decadeStart: 2020
  property int selectedDn: 0
  property int todayDn: 0

  signal picked(int value)            // a month 0-11, or a year
  signal step(int n)

  readonly property var sel: Cal.ymd(selectedDn)
  readonly property var now: Cal.ymd(todayDn)
  readonly property real gap: 8
  readonly property real cellW: (width - gap * 2) / 3
  readonly property real cellH: (height - gap * 3) / 4
  readonly property string key: mode + ":" + year + ":" + decadeStart

  onKeyChanged: fade.restart()

  NumberAnimation { id: fade; target: grid; property: "opacity"; from: 0.35; to: 1; duration: 170 }

  Item {
    id: grid
    anchors.fill: parent

    Repeater {
      model: 12
      delegate: Rectangle {
        id: cell
        required property int index
        readonly property int value: root.mode === 1 ? index : root.decadeStart - 1 + index
        readonly property bool outside: root.mode === 2 && (index === 0 || index === 11)
        readonly property bool isSel: root.mode === 1 ? (root.sel.y === root.year && root.sel.m === value) : root.sel.y === value
        readonly property bool isNow: root.mode === 1 ? (root.now.y === root.year && root.now.m === value) : root.now.y === value
        readonly property var counts: root.mode === 1
          ? CalendarStore.countRange(Cal.dayNumber(root.year, value, 1), Cal.dayNumber(root.year, value, Cal.daysInMonth(root.year, value)))
          : CalendarStore.countRange(Cal.dayNumber(value, 0, 1), Cal.dayNumber(value, 11, 31))

        x: (index % 3) * (root.cellW + root.gap)
        y: Math.floor(index / 3) * (root.cellH + root.gap)
        width: root.cellW
        height: root.cellH
        radius: Retro.corner
        color: isSel ? Theme.bgSel : Retro.inset
        border.width: Retro.borderWidth
        border.color: isNow ? Theme.orange : (mouse.containsMouse ? Theme.fg : Theme.fgDim)

        Text {
          x: 10
          y: 8
          text: root.mode === 1 ? Cal.MONTHS_SHORT[cell.value] : String(cell.value)
          color: cell.isNow ? Theme.orange : (cell.outside ? Theme.fgDim : Theme.fg)
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 2
        }

        Row {
          x: 10
          y: parent.height - 20
          spacing: 10
          Row { visible: cell.counts.h > 0; spacing: 4; Rectangle { y: 4; width: 6; height: 6; color: Theme.green } Text { text: cell.counts.h; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 2 } }
          Row { visible: cell.counts.e > 0; spacing: 4; Rectangle { y: 4; width: 6; height: 6; color: Theme.blue } Text { text: cell.counts.e; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 2 } }
          Row { visible: cell.counts.r > 0; spacing: 4; Rectangle { y: 4; width: 6; height: 6; color: Theme.orange } Text { text: cell.counts.r; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 2 } }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(cell.value)
        }
      }
    }
  }

  // drag: every 56 px moves one step (dragging down goes back in time)
  DragHandler {
    target: null
    property int taken: 0
    onActiveChanged: taken = 0
    onTranslationChanged: {
      const n = Math.trunc(translation.y / 56);
      if (n !== taken) {
        root.step(-(n - taken));
        taken = n;
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    property real acc: 0
    onWheel: wheel => {
      wheel.accepted = true;
      acc += wheel.angleDelta.y;
      while (Math.abs(acc) >= 120) {
        root.step(acc > 0 ? -1 : 1);
        acc -= acc > 0 ? 120 : -120;
      }
    }
  }
}
