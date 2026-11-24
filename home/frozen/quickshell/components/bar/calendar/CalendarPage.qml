import QtQuick
import qs
import qs.components.shared
import "../../../lib/calendar.js" as Cal

// The calendar tab: month grid on top (a continuous week scroller), the selected day's list below.
// Click the title to zoom out: month -> year -> decade. Click a cell to zoom back in.
Item {
  id: page

  property int selectedDn: 0
  property int level: 0                 // 0 = days, 1 = months of a year, 2 = years of a decade, 3 = the hours of one day

  signal editRequested(string kind, string id)

  readonly property var sel: Cal.ymd(selectedDn)
  readonly property int decade: Math.floor(sel.y / 10) * 10
  readonly property int shownYear: level === 0 ? weeks.focusYear : sel.y
  readonly property string titleText: level === 3 ? Cal.dayLabel(selectedDn) : level === 0 ? Cal.MONTHS[weeks.focusMonth] + " " + weeks.focusYear : (level === 1 ? String(sel.y) : decade + " - " + (decade + 9))

  onShownYearChanged: CalendarStore.ensureYear(shownYear, false)

  function reset() {
    level = 0;
    selectedDn = Clock.todayDn;
    Qt.callLater(function () {
      weeks.showMonth(page.sel.y, page.sel.m, false);
    });
  }

  function selectDn(dn, scroll) {
    selectedDn = Cal.clampDn(dn);
    if (level === 0 && scroll)
      weeks.ensureVisible(selectedDn);
  }

  function goToday() {
    level = 0;
    selectedDn = Clock.todayDn;
    weeks.showMonth(sel.y, sel.m, true);
  }

  // big: the double arrows (a year, a decade, a century)
  function nav(big, n) {
    if (level === 3) {
      selectDn(selectedDn + (big ? 7 : 1) * n, false);
      return;
    }
    if (level === 0) {
      const y = weeks.focusYear;
      const m = weeks.focusMonth;
      selectedDn = Cal.addMonths(Cal.dayNumber(y, m, Math.min(sel.d, Cal.daysInMonth(y, m))), big ? 12 * n : n);
      weeks.showMonth(sel.y, sel.m, true);
    } else {
      selectedDn = Cal.addMonths(selectedDn, 12 * n * (level === 1 ? (big ? 10 : 1) : (big ? 100 : 10)));
    }
  }

  function zoomOut() {
    if (level === 3) {
      level = 0;
      Qt.callLater(function () {
        weeks.showMonth(page.sel.y, page.sel.m, false);
      });
      return;
    }
    if (level === 0) {
      const y = weeks.focusYear;
      const m = weeks.focusMonth;
      if (sel.y !== y || sel.m !== m)
        selectedDn = Cal.dayNumber(y, m, Math.min(sel.d, Cal.daysInMonth(y, m)));
      level = 1;
    } else if (level === 1) {
      level = 2;
    }
  }

  function pickMonth(m) {
    const y = sel.y;
    selectedDn = Cal.dayNumber(y, m, Math.min(sel.d, Cal.daysInMonth(y, m)));
    level = 0;
    Qt.callLater(function () {
      weeks.showMonth(y, m, false);
    });
  }

  function pickYear(y) {
    selectedDn = Cal.dayNumber(y, sel.m, Math.min(sel.d, Cal.daysInMonth(y, sel.m)));
    level = 1;
  }

  function handleKey(event) {
    const k = event.key;
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
    const back = k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_PageUp;
    const fwd = k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_PageDown;

    if (k === Qt.Key_Home || k === Qt.Key_T) {
      goToday();
      return true;
    }
    if (k === Qt.Key_Backspace) {
      zoomOut();
      return true;
    }
    if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      if (level === 0)
        level = 3;
      else if (level === 1)
        pickMonth(sel.m);
      else if (level === 2)
        pickYear(sel.y);
      return true;
    }
    if (!back && !fwd)
      return false;

    const dir = back ? -1 : 1;
    const page1 = k === Qt.Key_PageUp || k === Qt.Key_PageDown;
    const vertical = k === Qt.Key_Up || k === Qt.Key_Down;

    if (level === 3) {
      selectedDn = Cal.clampDn(selectedDn + dir * (page1 ? 7 : 1));
      return true;
    }
    if (level === 0) {
      if (page1) {
        selectedDn = Cal.addMonths(selectedDn, dir * (ctrl ? 12 : 1));
        weeks.showMonth(sel.y, sel.m, true);
      } else {
        selectDn(selectedDn + dir * (vertical ? 7 : 1), true);
      }
    } else {
      const per = page1 ? (level === 1 ? 12 : 10) : (vertical ? 3 : 1);
      selectedDn = Cal.addMonths(selectedDn, dir * per * (level === 1 ? 1 : 12));
    }
    return true;
  }

  // ---- navigation row ----
  Item {
    id: nav
    width: parent.width
    height: 26

    MiniButton { id: bBack; height: 26; anchors.left: parent.left; text: "<<"; onClicked: page.nav(true, -1) }
    MiniButton { id: sBack; height: 26; anchors { left: bBack.right; leftMargin: 4 } text: "<"; onClicked: page.nav(false, -1) }
    MiniButton { id: today; height: 26; anchors.right: parent.right; text: "TODAY"; onClicked: page.goToday() }
    MiniButton { id: bFwd; height: 26; anchors { right: today.left; rightMargin: 4 } text: ">>"; onClicked: page.nav(true, 1) }
    MiniButton { id: sFwd; height: 26; anchors { right: bFwd.left; rightMargin: 4 } text: ">"; onClicked: page.nav(false, 1) }
    MiniButton {
      height: 26
      anchors { left: sBack.right; right: sFwd.left; leftMargin: 4; rightMargin: 4 }
      text: page.titleText
      onClicked: page.zoomOut()
    }
  }

  // ---- the grid ----
  Item {
    id: body
    y: 34
    width: parent.width
    height: 250
    visible: page.level !== 3

    WeekList {
      id: weeks
      anchors.fill: parent
      visible: page.level === 0
      mondayFirst: CalendarStore.settings.weekStartsMonday
      selectedDn: page.selectedDn
      todayDn: Clock.todayDn
      onDaySelected: dn => page.selectDn(dn, false)
      onDayOpened: dn => {
        page.selectDn(dn, false);
        page.level = 3;
      }
      onWheelMonths: n => page.nav(false, n)
    }

    PeriodGrid {
      anchors.fill: parent
      visible: page.level === 1 || page.level === 2
      mode: page.level === 2 ? 2 : 1
      year: page.sel.y
      decadeStart: page.decade
      selectedDn: page.selectedDn
      todayDn: Clock.todayDn
      onPicked: value => page.level === 1 ? page.pickMonth(value) : page.pickYear(value)
      onStep: n => page.selectedDn = Cal.addMonths(page.selectedDn, 12 * n * (page.level === 1 ? 1 : 10))
    }
  }

  // ---- the selected day ----
  Rectangle {
    id: divider
    y: body.y + body.height + 8
    width: parent.width
    height: 2
    visible: page.level !== 3
    color: Theme.fgDim
  }

  Text {
    id: dayTitle
    y: divider.y + 8
    width: parent.width - 80
    visible: page.level !== 3
    elide: Text.ElideRight
    text: Cal.dayLabel(page.selectedDn)
    color: Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize
  }

  MiniButton {
    anchors { right: parent.right; verticalCenter: dayTitle.verticalCenter }
    visible: page.level !== 3
    text: "HOURS"
    onClicked: page.level = 3
  }

  AgendaList {
    anchors { left: parent.left; right: parent.right; top: dayTitle.bottom; bottom: parent.bottom; topMargin: 8 }
    visible: page.level !== 3
    dn: page.selectedDn
    onEdit: (kind, id) => page.editRequested(kind, id)
  }

  DayView {
    anchors { left: parent.left; right: parent.right; top: nav.bottom; bottom: parent.bottom; topMargin: 8 }
    visible: page.level === 3
    dn: page.selectedDn
    onEdit: (kind, id) => page.editRequested(kind, id)
  }
}
