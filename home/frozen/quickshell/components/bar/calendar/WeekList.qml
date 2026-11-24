import QtQuick
import qs
import "../../../lib/calendar.js" as Cal

// The days as one long scrolling list of weeks: drag it, flick it, or use the wheel (one week a notch,
// Ctrl+wheel one month). Only the rows in view exist, so scrolling from 1900 to 2199 costs nothing.
Item {
  id: root

  property bool mondayFirst: false
  property int selectedDn: 0
  property int todayDn: 0

  readonly property real rowH: 38
  readonly property int rows: 6
  readonly property int anchorDn: Cal.weekAnchor(mondayFirst)
  readonly property int weekTotal: Cal.weekCount(mondayFirst)

  property int focusYear: 2026          // the month in the middle of the window
  property int focusMonth: 0

  signal daySelected(int dn)
  signal dayOpened(int dn)
  signal wheelMonths(int n)

  function scrollTo(y, animate) {
    const t = Math.max(0, Math.min(flick.contentHeight - flick.height, y));
    scroller.stop();
    if (animate) {
      scroller.from = flick.contentY;
      scroller.to = t;
      scroller.start();
    } else {
      flick.contentY = t;
    }
  }

  function scrollToWeek(w, animate) {
    scrollTo(w * rowH, animate);
  }

  // the first week of a month at the top
  function showMonth(y, m, animate) {
    scrollToWeek(Cal.weekIndexOf(Cal.dayNumber(y, m, 1), mondayFirst), animate);
  }

  function scrollWeeks(n) {
    const base = scroller.running ? scroller.to : flick.contentY;
    scrollTo((Math.round(base / rowH) + n) * rowH, true);
  }

  // scroll only as far as needed to bring a day into view
  function ensureVisible(dn) {
    const w = Cal.weekIndexOf(dn, mondayFirst);
    const y = scroller.running ? scroller.to : flick.contentY;
    if (w * rowH < y)
      scrollToWeek(w, true);
    else if ((w + 1) * rowH > y + flick.height)
      scrollToWeek(w - (rows - 1), true);
  }

  function updateFocus() {
    const r = Math.floor((flick.contentY + flick.height / 2) / rowH);
    const t = Cal.ymd(anchorDn + r * 7 + 3);
    focusYear = t.y;
    focusMonth = t.m;
  }

  onMondayFirstChanged: Qt.callLater(function () {
    root.showMonth(root.focusYear, root.focusMonth, false);
  })

  Row {
    id: header
    width: parent.width
    height: 20

    Repeater {
      model: 7
      delegate: Text {
        required property int index
        width: header.width / 7
        horizontalAlignment: Text.AlignHCenter
        text: Cal.DAYS_SHORT[(index + (root.mondayFirst ? 1 : 0)) % 7]
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }
    }
  }

  Flickable {
    id: flick
    anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; topMargin: 2 }
    clip: true
    contentWidth: width
    contentHeight: root.weekTotal * root.rowH
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    flickDeceleration: 3000
    maximumFlickVelocity: 3500

    onContentYChanged: root.updateFocus()
    onMovementStarted: scroller.stop()
    onMovementEnded: {
      const t = Math.round(flick.contentY / root.rowH) * root.rowH;
      if (Math.abs(t - flick.contentY) > 0.5)
        root.scrollTo(t, true);
    }

    NumberAnimation {
      id: scroller
      target: flick
      property: "contentY"
      duration: 200
      easing.type: Easing.OutCubic
    }

    Repeater {
      model: root.rows + 3
      delegate: Item {
        id: week
        required property int index
        readonly property int w: Math.max(0, Math.floor(flick.contentY / root.rowH) - 1) + index

        y: w * root.rowH
        width: flick.width
        height: root.rowH
        visible: w < root.weekTotal

        Repeater {
          model: 7
          delegate: DayCell {
            required property int index
            x: index * (week.width / 7)
            width: week.width / 7
            height: week.height
            dn: root.anchorDn + week.w * 7 + index
            selected: dn === root.selectedDn
            today: dn === root.todayDn
            focusKey: root.focusYear * 12 + root.focusMonth
            onPicked: root.daySelected(dn)
            onOpened: root.dayOpened(dn)
          }
        }
      }
    }
  }

  // the wheel (a MouseArea that takes no buttons, so clicks and drags pass through)
  MouseArea {
    anchors.fill: flick
    acceptedButtons: Qt.NoButton
    property real acc: 0
    onWheel: wheel => {
      wheel.accepted = true;
      acc += wheel.angleDelta.y;
      while (Math.abs(acc) >= 120) {
        const dir = acc > 0 ? -1 : 1;
        acc -= acc > 0 ? 120 : -120;
        if (wheel.modifiers & Qt.ControlModifier)
          root.wheelMonths(dir);
        else
          root.scrollWeeks(dir);
      }
    }
  }
}
