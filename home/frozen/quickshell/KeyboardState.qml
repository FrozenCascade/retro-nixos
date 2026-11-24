pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Live keyboard state from Hyprland: caps lock, the active layout, and switching layouts.
// The layouts themselves are listed in settings.nix (Settings.keyboardLayouts).
Singleton {
  id: root

  property bool capsLock: false
  property string activeKeymap: ""      // exactly what Hyprland reports, e.g. "English (US)"
  property int activeIndex: -1          // position in Settings.keyboardLayouts, -1 = not recognised

  readonly property var layouts: Settings.keyboardLayouts
  readonly property string activeShort: activeIndex >= 0 ? layouts[activeIndex].short : "??"
  readonly property string activeName: activeIndex >= 0 ? layouts[activeIndex].name : activeKeymap

  function refresh() {
    if (!devices.running)
      devices.running = true;
  }

  function switchTo(index) {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(index)]);
    activeIndex = index;
    soon.restart();
  }

  // like Super+': the next layout
  function next() {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    if (activeIndex >= 0 && layouts.length > 0)
      activeIndex = (activeIndex + 1) % layouts.length;
    soon.restart();
  }

  function parse(text) {
    let data = null;
    try {
      data = JSON.parse(text);
    } catch (e) {
      return;
    }

    const keyboards = data.keyboards || [];
    if (keyboards.length === 0)
      return;

    // caps lock is on if any keyboard says so
    capsLock = keyboards.some(k => k.capsLock === true);

    // the layout comes from the keyboard you typed on last
    const main = keyboards.find(k => k.main === true) || keyboards[0];
    activeKeymap = main.active_keymap || "";

    if (typeof main.active_layout_index === "number")
      activeIndex = main.active_layout_index;
    else
      activeIndex = layouts.findIndex(l => l.name === activeKeymap);
  }

  Process {
    id: devices
    command: ["hyprctl", "devices", "-j"]

    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  // Hyprland has no event for caps lock, so ask twice a second. Layout changes also arrive as an event.
  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // after a switch: look again right away
  Timer {
    id: soon
    interval: 150
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "activelayout")
        root.refresh();
    }
  }
}
