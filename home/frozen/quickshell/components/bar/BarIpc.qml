import Quickshell.Io
import QtQuick
import qs

// What the keyboard can ask of the bar:  qs ipc call bar <function>
//   toggle <popup>   status, weather, quick, calendar, overview, ai, tool-audio, tool-display,
//                    tool-connections, tool-session, tool-studio
//   closeAll         close every popup
//   quick <tab>      the quick window on a tab: 0 notes, 1 clipboard, 2 layouts
//   pin              pin or unpin the top bar
//   vpn              VPN on or off
// The key binds are in hypr/shortcuts.lua (Super + letter) and hypr/keys.lua (function keys).
Item {
  id: root

  required property var popups          // PopupController
  required property var hider           // AutoHide

  IpcHandler {
    target: "bar"

    function toggle(name: string): void {
      root.popups.toggle(name);
    }

    function closeAll(): void {
      root.popups.closeAll();
    }

    function quick(tab: int): void {
      root.popups.quickTab = tab;
      root.popups.toggle("quick");
    }

    function pin(): void {
      root.hider.togglePinned();
    }

    function vpn(): void {
      NetState.vpnToggle();
    }
  }
}
