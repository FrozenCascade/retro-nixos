import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// Connections: four big switches on top (Wi-Fi, Bluetooth, VPN, Airplane), and a tab for each kind of
// connection below. All state lives in NetState.
// To add a tab: put its file in this folder, add its name to tabNames and a page below.
ToolWindow {
  id: win

  name: "connections"
  title: "CONNECTIONS"

  property int tab: 0
  readonly property var tabNames: ["WI-FI", "BLUETOOTH", "VPN", "PHONES"]

  // poll faster while the window is open
  Binding {
    target: NetState
    property: "watching"
    value: win.open
  }

  onOpened: {
    tab = 0;
    NetState.refresh();
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
    id: tiles
    width: parent.width
    spacing: 6

    Tile {
      width: (tiles.width - 18) / 4
      compact: true
      labelSize: Theme.fontSize - 3
      glyph: NetState.wifiBarGlyph
      label: "WI-FI"
      active: NetState.wifiEnabled
      onActivated: NetState.setWifi(!NetState.wifiEnabled)
    }

    Tile {
      width: (tiles.width - 18) / 4
      compact: true
      labelSize: Theme.fontSize - 3
      glyph: NetState.btEnabled ? Glyphs.bluetooth : Glyphs.bluetoothOff
      label: "BLUETOOTH"
      active: NetState.btEnabled
      onActivated: NetState.setBt(!NetState.btEnabled)
    }

    Tile {
      width: (tiles.width - 18) / 4
      compact: true
      labelSize: Theme.fontSize - 3
      glyph: Glyphs.vpn
      label: "VPN"
      active: NetState.vpnUp
      onActivated: NetState.vpnToggle()
    }

    Tile {
      width: (tiles.width - 18) / 4
      compact: true
      labelSize: Theme.fontSize - 3
      glyph: Glyphs.airplane
      label: "AIRPLANE"
      active: NetState.airplane
      confirm: !NetState.airplane       // asks SURE? before switching everything off, not when coming back
      onActivated: NetState.setAirplane(!NetState.airplane)
    }
  }

  Row {
    id: tabs
    y: 66
    width: parent.width
    spacing: 6

    Repeater {
      model: win.tabNames

      RetroTab {
        required property int index
        required property string modelData

        width: (tabs.width - 6 * (win.tabNames.length - 1)) / win.tabNames.length
        label: modelData
        selected: win.tab === index
        onClicked: win.select(index)
      }
    }
  }

  Item {
    y: 106
    width: parent.width
    height: parent.height - 106

    WifiTab { anchors.fill: parent; visible: win.tab === 0 }
    BluetoothTab { anchors.fill: parent; visible: win.tab === 1 }
    VpnTab { anchors.fill: parent; visible: win.tab === 2 }
    PhonesTab { anchors.fill: parent; visible: win.tab === 3; active: visible && win.open }
  }
}
