import QtQuick
import qs
import qs.components.shared
import qs.components.bar.quick
import "../../../lib/calendar.js" as Cal

// The calendar window: the calendar, a planner tab and a "MISC" tab.
// The window, frame and focus rules live in FramedWindow; this file holds only the calendar's own layout.
Item {
  id: root

  property bool open: false
  property bool pinned: false
  property bool held: false             // stays open when it loses focus to a window it may coexist with

  signal closeRequested
  signal pinToggled

  // The Hyprland rule "qs-calendar" in hyprland.lua must be this size plus the shadow (frame + 4).
  readonly property real frameWidth: 480
  readonly property real frameHeight: 720

  property int tab: 0                   // 0 = calendar, 1 = planner, 2 = misc
  readonly property int tabCount: 3

  onOpenChanged: {
    if (open) {
      tab = 0;
      calPage.reset();
      plannerPage.reset();
      miscPage.reset();
      Clock.refresh();
    }
  }

  function setTab(i) {
    tab = i;
    win.panel.forceActiveFocus();
  }

  function handleKey(event) {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
    if (ctrl) {
      switch (event.key) {
        case Qt.Key_1:
          setTab(0);
          break;
        case Qt.Key_2:
          setTab(1);
          break;
        case Qt.Key_3:
          setTab(2);
          break;
        case Qt.Key_Z:
          if (QuickUndo.pending === null)
            return;
          QuickUndo.undo();
          break;
        default:
          if (tab === 0 && calPage.handleKey(event))
            break;
          return;
      }
      event.accepted = true;
      return;
    }

    switch (event.key) {
      case Qt.Key_Escape:
        if (!pinned)
          closeRequested();
        break;
      case Qt.Key_Tab:
        setTab((tab + 1) % tabCount);
        break;
      case Qt.Key_Backtab:
        setTab((tab + tabCount - 1) % tabCount);
        break;
      case Qt.Key_N:
        plannerPage.newItem();
        setTab(1);
        plannerPage.focusTitle();
        break;
      default:
        if (tab === 0 && calPage.handleKey(event))
          break;
        return;
    }
    event.accepted = true;
  }

  FramedWindow {
    id: win
    windowTitle: "qs-calendar"
    title: "Calendar"
    open: root.open
    pinned: root.pinned
    held: root.held
    frameWidth: root.frameWidth
    frameHeight: root.frameHeight
    onCloseRequested: root.closeRequested()
    onPinToggled: root.pinToggled()
    onKeyPressed: event => root.handleKey(event)

    // today and the zone in use
    Item {
      x: 14
      y: 32
      width: parent.width - 28
      height: 28

      Text {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: Cal.dayLabel(Clock.todayDn)
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize
      }

      Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 170
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        text: Clock.zoneName
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }
    }

    Rectangle {
      x: 14
      y: 62
      width: parent.width - 28
      height: 2
      color: Theme.fgDim
    }

    Row {
      id: tabs
      x: 14
      y: 72
      width: parent.width - 28
      spacing: 8

      RetroTab { width: (tabs.width - 16) / 3; label: "CALENDAR"; selected: root.tab === 0; onClicked: root.setTab(0) }
      RetroTab { width: (tabs.width - 16) / 3; label: "PLANNER"; selected: root.tab === 1; onClicked: root.setTab(1) }
      RetroTab { width: (tabs.width - 16) / 3; label: "MISC"; selected: root.tab === 2; onClicked: root.setTab(2) }
    }

    Item {
      x: 14
      y: 112
      width: parent.width - 28
      height: parent.height - 112 - 54

      CalendarPage {
        id: calPage
        anchors.fill: parent
        visible: root.tab === 0
        onEditRequested: (kind, id) => {
          plannerPage.startEdit(kind, id);
          root.setTab(1);
        }
      }

      PlannerPage {
        id: plannerPage
        anchors.fill: parent
        visible: root.tab === 1
        active: visible
        selectedDn: calPage.selectedDn
        onFinishedEdit: dn => {
          calPage.selectDn(dn, true);
          root.setTab(0);
        }
        onLeaveField: win.panel.forceActiveFocus()
      }

      MiscPage {
        id: miscPage
        anchors.fill: parent
        visible: root.tab === 2
        active: visible
      }
    }

    // footer: the undo strip, or the key hints
    Item {
      x: 14
      y: parent.height - 46
      width: parent.width - 28
      height: 24

      UndoToast {
        anchors.fill: parent
        visible: QuickUndo.pending !== null
      }

      Text {
        anchors.fill: parent
        visible: QuickUndo.pending === null
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.tab === 0 ? "ARROWS DAY/WEEK  PGUP PGDN MONTH  ENTER HOURS  T TODAY  N NEW" : (root.tab === 1 ? "ENTER ADDS  ESC LEAVES A FIELD  TAB NEXT TAB" : "CLICK A BLOCK TO COPY IT")
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }
  }
}
