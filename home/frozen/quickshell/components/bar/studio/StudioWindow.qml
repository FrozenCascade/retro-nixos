import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// Studio: media player, playlist library, screenshots, screen recording and downloads.
// To add a tab: put its file in this folder, add its name to tabNames and a page below.
ToolWindow {
  id: win

  name: "studio"
  title: "STUDIO"
  frameWidth: 640                    // wider than the other tools; the size rule is in hypr/studio.lua

  property int tab: 0
  readonly property var tabNames: ["PLAYER", "LIBRARY", "CAPTURE", "RECORD", "DOWNLOAD", "ICONS"]

  // the same order as tabNames; StudioState.reveal() names a tab by these
  readonly property var tabIds: ["player", "library", "capture", "record", "download"]

  function showPending() {
    const i = tabIds.indexOf(StudioState.pendingTab);
    if (i >= 0)
      select(i);
    StudioState.pendingTab = "";
  }

  onOpened: {
    tab = 0;
    showPending();
  }

  Connections {
    target: StudioState

    function onRevealRequested() {
      if (win.open)
        win.showPending();
    }
  }

  function select(i) {
    tab = Math.max(0, Math.min(tabNames.length - 1, i));
  }

  // Ctrl+1..6 or PageUp/PageDown change the tab
  onKeyPressed: event => {
    if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key < Qt.Key_1 + tabNames.length) {
      select(event.key - Qt.Key_1);
      event.accepted = true;
    } else if (event.key === Qt.Key_PageDown) {
      select(tab + 1);
      event.accepted = true;
    } else if (event.key === Qt.Key_PageUp) {
      select(tab - 1);
      event.accepted = true;
    }
  }

  Row {
    id: tabs
    width: parent.width
    spacing: 8

    Repeater {
      model: win.tabNames

      RetroTab {
        required property int index
        required property string modelData

        width: (tabs.width - 8 * (win.tabNames.length - 1)) / win.tabNames.length
        label: modelData
        selected: win.tab === index
        onClicked: win.select(index)
      }
    }
  }

  Item {
    y: 42
    width: parent.width
    height: parent.height - 42

    PlayerTab { anchors.fill: parent; visible: win.tab === 0 }
    LibraryTab { anchors.fill: parent; visible: win.tab === 1 }
    CaptureTab { anchors.fill: parent; visible: win.tab === 2 }
    RecordTab { anchors.fill: parent; visible: win.tab === 3 }
    DownloadTab { anchors.fill: parent; visible: win.tab === 4 }
    IconsTab { anchors.fill: parent; visible: win.tab === 5 }
  }
}
