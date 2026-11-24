import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// Display: brightness per monitor, night light, and the wallpaper of each monitor.
// To add a tab: put its file in this folder, add its name to tabNames and a page below.
ToolWindow {
  id: win

  name: "display"
  title: "DISPLAY"

  property int tab: 0
  readonly property var tabNames: ["BRIGHTNESS", "NIGHT LIGHT", "WALLPAPER", "KEYBOARD"]

  onOpened: {
    tab = 0;
    DisplayState.refreshPanel();
  }

  function select(i) {
    tab = Math.max(0, Math.min(tabNames.length - 1, i));
  }

  // Ctrl+1..4 or PageUp/PageDown change the tab
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

    BrightnessTab { anchors.fill: parent; visible: win.tab === 0 }
    NightLightTab { anchors.fill: parent; visible: win.tab === 1 }
    WallpaperTab { anchors.fill: parent; visible: win.tab === 2 }
    KeyboardTab { anchors.fill: parent; visible: win.tab === 3 }
  }
}
