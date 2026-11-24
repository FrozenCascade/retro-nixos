import Quickshell.Hyprland
import QtQuick
import qs

// Decides which window the top bar shows, and ignores Quickshell's own windows:
// while one of them has the keyboard, the last real window stays.
Item {
  id: tracker

  property string workspace: ""          // the workspace this bar's monitor is showing
  property var window: null              // the window to show, or null when nothing is focused here

  readonly property var focused: Hyprland.toplevels.values.find(t => t.activated) || null

  function update() {
    const f = focused;

    // nothing is focused: an empty workspace
    if (f === null) {
      window = null;
      return;
    }

    // a Quickshell window has the keyboard: keep showing the last real window
    if (Desktop.isShell(f))
      return;

    // a window on another monitor does not count for this bar
    window = (f.workspace && f.workspace.name === workspace) ? f : null;
  }

  onFocusedChanged: update()
  onWorkspaceChanged: update()
  Component.onCompleted: update()
}
