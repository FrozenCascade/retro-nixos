import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar
import qs.components.bar.tools

// Audio, modelled on KDE's volume widget: OUTPUT (playback devices), INPUT (recording devices) and
// APPLICATIONS, with a search box under the tabs.
ToolWindow {
  id: win

  name: "audio"
  title: "AUDIO"

  property int tab: 0                   // 0 output, 1 input, 2 applications

  // Ctrl+1/2/3 or PageUp/PageDown change the tab, "/" jumps to the search box
  onKeyPressed: event => {
    if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
      select(event.key - Qt.Key_1);
      event.accepted = true;
    } else if (event.key === Qt.Key_PageDown) {
      select(Math.min(2, tab + 1));
      event.accepted = true;
    } else if (event.key === Qt.Key_PageUp) {
      select(Math.max(0, tab - 1));
      event.accepted = true;
    } else if (event.key === Qt.Key_Slash) {
      search.focusIt();
      event.accepted = true;
    }
  }

  function select(i) {
    tab = i;
    search.text = "";
  }

  Row {
    id: tabs
    width: parent.width
    spacing: 8

    RetroTab { width: (tabs.width - 16) / 3; label: "OUTPUT"; selected: win.tab === 0; onClicked: win.select(0) }
    RetroTab { width: (tabs.width - 16) / 3; label: "INPUT"; selected: win.tab === 1; onClicked: win.select(1) }
    RetroTab { width: (tabs.width - 16) / 3; label: "APPLICATIONS"; selected: win.tab === 2; onClicked: win.select(2) }
  }

  FieldBox {
    id: search
    y: 38
    width: parent.width
    height: 28
    placeholder: win.tab === 2 ? "SEARCH APPLICATIONS" : "SEARCH DEVICES"
    onEscaped: text = ""
  }

  Item {
    y: 76
    width: parent.width
    height: parent.height - 76

    DevicesTab { anchors.fill: parent; visible: win.tab === 0; mode: "output"; query: search.text.trim().toLowerCase() }
    DevicesTab { anchors.fill: parent; visible: win.tab === 1; mode: "input"; query: search.text.trim().toLowerCase() }
    AppsTab { anchors.fill: parent; visible: win.tab === 2; query: search.text.trim().toLowerCase() }
  }
}
