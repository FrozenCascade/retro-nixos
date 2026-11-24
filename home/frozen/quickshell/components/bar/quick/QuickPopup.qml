import QtQuick
import qs
import qs.components.shared

// The quick window: notes, clipboard history and keyboard layouts in one place.
//
// The window, frame and focus rules live in FramedWindow. This file holds what the pages share: the
// status line, the tabs, the search box, the keys and the footer. Each page (NotesPage, ClipboardPage,
// LayoutsPage) does its own work and offers the same small interface, described at the top of NotesPage.
Item {
  id: root

  property bool open: false
  property bool pinned: false
  property bool held: false             // stays open when it loses focus to a window it may coexist with

  signal closeRequested
  signal pinToggled

  // The Hyprland rule "qs-quick" in hyprland.lua must be this size plus the shadow (frame + 4).
  readonly property real frameWidth: 600
  readonly property real frameHeight: 600

  property int startTab: 0              // the tab a fresh opening starts on
  property int tab: 0                  // 0 = notes, 1 = clipboard, 2 = layouts
  property bool confirming: false      // the "delete all?" question is showing

  readonly property var pageList: [notesPage, clipPage, layoutPage]
  readonly property var currentPage: pageList[tab]

  // the window just opened (or closed)
  onOpenChanged: {
    confirming = false;
    if (open) {
      tab = startTab;
      search.text = "";
      ClipHistory.refresh();
      for (const p of pageList)
        p.reset();
    } else {
      notesPage.leave();
    }
  }

  function setTab(i) {
    if (i === tab)
      return;
    currentPage.leave();
    confirming = false;
    tab = i;
    search.text = "";
    currentPage.reset();
    search.forceActiveFocus();
  }

  // After something was copied or switched: close, unless the window is pinned.
  function finished() {
    if (!pinned)
      closeRequested();
  }

  // Keys that work whether the keyboard is in the search box or in a note.
  function handleKey(event) {
    if (!(event.modifiers & Qt.ControlModifier))
      return;

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
      case Qt.Key_N:
        setTab(0);
        notesPage.newNote("");
        break;
      case Qt.Key_P:
        currentPage.togglePin();
        break;
      case Qt.Key_D:
        currentPage.removeSelected();
        break;
      case Qt.Key_C:
        // plain Ctrl+C stays the normal copy
        if (!(event.modifiers & Qt.ShiftModifier))
          return;
        currentPage.copySelected();
        break;
      case Qt.Key_Z:
        // nothing to undo here: the note's own undo works
        if (QuickUndo.pending === null)
          return;
        QuickUndo.undo();
        break;
      default:
        return;
    }
    event.accepted = true;
  }

  // new clipboard entries show up while the clipboard tab is open
  Timer {
    interval: 2000
    repeat: true
    running: root.open && root.tab === 1
    onTriggered: ClipHistory.refresh()
  }

  FramedWindow {
    id: win
    windowTitle: "qs-quick"
    title: "Notebook"
    open: root.open
    pinned: root.pinned
    held: root.held
    frameWidth: root.frameWidth
    frameHeight: root.frameHeight
    focusTarget: search               // the keyboard starts in the search box
    clickFocusesFrame: false          // a click on empty space must not pull it out of a note
    onCloseRequested: root.closeRequested()
    onPinToggled: root.pinToggled()

    // ================= status line, styled like the battery line in the system popup =================
    // the layout in use on the left, caps lock on the right, on every tab
    Item {
      id: status
      x: 14
      y: 32
      width: parent.width - 28
      height: 28

      Row {
        anchors {
          left: parent.left
          right: capsText.left
          verticalCenter: parent.verticalCenter
          rightMargin: 10
        }
        spacing: 8

        Text {
          id: layoutShort
          anchors.verticalCenter: parent.verticalCenter
          text: KeyboardState.activeShort
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 2
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: status.width - layoutShort.width - capsText.width - 38
          elide: Text.ElideRight
          text: KeyboardState.activeName
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      Text {
        id: capsText
        anchors {
          right: parent.right
          verticalCenter: parent.verticalCenter
        }
        text: KeyboardState.capsLock ? "CAPS ON" : "CAPS OFF"
        color: KeyboardState.capsLock ? Theme.orange : Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }

    // divider, like the Rule in the system popup
    Rectangle {
      x: 14
      y: 62
      width: parent.width - 28
      height: 2
      color: Theme.fgDim
    }

    // ================= tabs =================
    Row {
      id: tabs
      x: 14
      y: 72
      width: parent.width - 28
      spacing: 8

      RetroTab {
        width: (tabs.width - 16) / 3
        label: "NOTES"
        selected: root.tab === 0
        onClicked: root.setTab(0)
      }

      RetroTab {
        width: (tabs.width - 16) / 3
        label: "CLIPBOARD"
        selected: root.tab === 1
        onClicked: root.setTab(1)
      }

      RetroTab {
        width: (tabs.width - 16) / 3
        label: "LAYOUT"
        selected: root.tab === 2
        onClicked: root.setTab(2)
      }
    }

    // ================= search (filters notes, clipboard history or layouts) =================
    Rectangle {
      id: searchBox
      x: 14
      y: 110
      width: parent.width - 28
      height: 34
      radius: Retro.corner
      color: Retro.inset

      // yellow only while the keyboard is in this box
      border.color: search.activeFocus ? Theme.yellow : Theme.fgDim
      border.width: Retro.borderWidth

      Text {
        id: prompt
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
          leftMargin: 12
        }
        text: "/"
        color: Theme.yellow
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 1
      }

      Text {
        anchors {
          left: prompt.right
          verticalCenter: parent.verticalCenter
          leftMargin: 10
        }
        visible: search.text === ""
        text: root.currentPage.placeholder
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize
      }

      TextInput {
        id: search
        anchors {
          left: prompt.right
          right: parent.right
          top: parent.top
          bottom: parent.bottom
          leftMargin: 10
          rightMargin: 12
        }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectByMouse: true
        clip: true
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize + 1

        onAccepted: root.currentPage.activate()

        // pinned windows ignore Esc (use the x); otherwise it closes. Esc also cancels "delete all?".
        Keys.onEscapePressed: {
          if (root.confirming)
            root.confirming = false;
          else if (!root.pinned)
            root.closeRequested();
        }
        Keys.onUpPressed: root.currentPage.move(-1)
        Keys.onDownPressed: root.currentPage.move(1)
        Keys.onTabPressed: root.setTab((root.tab + 1) % 3)
        Keys.onBacktabPressed: root.setTab((root.tab + 2) % 3)
        Keys.onPressed: event => root.handleKey(event)
      }
    }

    // ================= pages (each keeps its own state while you look at another) =================
    Item {
      id: pages
      x: 14
      y: 152
      width: parent.width - 28
      height: parent.height - 152 - 54

      NotesPage {
        id: notesPage
        anchors.fill: parent
        visible: root.tab === 0
        active: visible
        query: search.text
        onDone: root.finished()
        onFocusSearch: search.forceActiveFocus()
        onKeyEvent: event => root.handleKey(event)
      }

      ClipboardPage {
        id: clipPage
        anchors.fill: parent
        visible: root.tab === 1
        active: visible
        query: search.text
        onDone: root.finished()
        onFocusSearch: search.forceActiveFocus()
      }

      LayoutsPage {
        id: layoutPage
        anchors.fill: parent
        visible: root.tab === 2
        active: visible
        query: search.text
        onDone: root.finished()
        onFocusSearch: search.forceActiveFocus()
      }
    }

    // ================= footer: "delete all?", or the undo strip, or the key hints =================
    Item {
      id: footer
      x: 14
      y: parent.height - 46
      width: parent.width - 28
      height: 24

      ConfirmStrip {
        anchors.fill: parent
        visible: root.confirming
        what: root.currentPage.clearWhat
        onYes: {
          root.currentPage.clearAll();
          root.confirming = false;
        }
        onNo: root.confirming = false
      }

      UndoToast {
        anchors.fill: parent
        visible: !root.confirming && QuickUndo.pending !== null
      }

      Item {
        anchors.fill: parent
        visible: !root.confirming && QuickUndo.pending === null

        Text {
          anchors {
            left: parent.left
            right: clearButton.left
            verticalCenter: parent.verticalCenter
            rightMargin: 10
          }
          elide: Text.ElideRight
          text: root.currentPage.hint
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }

        MiniButton {
          id: clearButton
          anchors.right: parent.right
          visible: root.currentPage.canClear
          text: "DELETE ALL"
          danger: true
          onClicked: root.confirming = true
        }
      }

      // the question goes away by itself if you do not answer it
      Timer {
        interval: 6000
        running: root.confirming
        onTriggered: root.confirming = false
      }
    }
  }
}
