import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// Session: two tabs. USER is you, the switches, your status apps and the notification history;
// SYSTEM is a summary of this machine and the power buttons.
// To add a tab: put its file in this folder, add its name to tabNames and a page below.
ToolWindow {
  id: win

  name: "session"
  title: "SESSION"

  property int tab: 0
  readonly property var tabNames: ["USER", "SYSTEM"]

  onOpened: {
    tab = 0;
    NotifStore.markRead();
    SessionState.refreshFacts();
  }

  function select(i) {
    tab = Math.max(0, Math.min(tabNames.length - 1, i));
  }

  // Ctrl+1..2 or PageUp/PageDown change the tab
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

    UserTab { anchors.fill: parent; visible: win.tab === 0; window: win.window }
    SystemTab { anchors.fill: parent; visible: win.tab === 1 }
  }
}
