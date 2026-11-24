pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs

// The in-shell screenshot editor (AnnotateOverlay.qml). It edits the last capture and writes the result
// back over it, so the CAPTURE tab preview and the clipboard show the marked-up picture.
// The first time a capture is edited, studio-shot keeps an untouched copy (original); REVERT in the editor
// goes back to it. A new capture or an import replaces that copy.
// Open it from the ANNOTATE button, the notification, or:  qs ipc call studio annotate
Singleton {
  id: root

  property bool active: false
  property string screenName: ""           // the monitor the editor opens on: the one you are working on
  readonly property string original: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/studio/original.png"

  function open() {
    if (active || keep.running || StudioState.lastShot === "")
      return;
    const focused = Hyprland.focusedMonitor;
    const first = Array.from(Quickshell.screens)[0];
    screenName = focused ? focused.name : (first ? first.name : "");
    keep.running = true;                   // the original is kept first, then the editor opens
  }

  function close() {
    active = false;
  }

  Process {
    id: keep
    command: [Tools.studioShot, "backup"]
    onExited: code => {
      if (code === 0)
        root.active = true;
    }
  }
}
