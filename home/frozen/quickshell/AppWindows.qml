pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Finds the open windows of an application (given its launcher entry) and brings one of them forward.
// Used by the launcher: right click or Ctrl+Enter = focus the app if it is open here, start it if not.
Singleton {
  id: root

  // false: only windows on the workspace you are on count. true: windows on any workspace do too.
  readonly property bool anyWorkspace: false

  readonly property string workspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : ""

  function hidden(t) {
    return t.workspace.name.indexOf("hidden_") !== -1;
  }

  // on this workspace, minimized windows included
  function here(t) {
    return t.workspace.name === workspace || t.workspace.name.endsWith("hidden_" + workspace);
  }

  // window class names that mean this entry: its id, its StartupWMClass and the classes from settings.nix (apps)
  function classesOf(entry) {
    const names = [entry.id, entry.startupClass];
    const o = Desktop.override(entry.id);
    if (o && o.classes)
      names.push(...o.classes);
    return names.filter(n => n).map(n => String(n).toLowerCase());
  }

  function belongs(t, entry, names) {
    const id = t.wayland && t.wayland.appId ? t.wayland.appId : "";
    if (id === "")
      return false;
    if (names.indexOf(id.toLowerCase()) !== -1)
      return true;

    const e = DesktopEntries.heuristicLookup(id);
    return !!e && e.id === entry.id;
  }

  function windowsOf(entry) {
    const names = classesOf(entry);
    return Hyprland.toplevels.values.filter(t => t.workspace && !Desktop.isShell(t) && belongs(t, entry, names) && (anyWorkspace || here(t)));
  }

  // Brings one window of the app forward; asking again moves on to the next one. false = none is open.
  function focus(entry) {
    const mine = windowsOf(entry);
    if (mine.length === 0)
      return false;

    const visible = mine.filter(t => !hidden(t));

    // everything is minimized: bring the first one back
    if (visible.length === 0) {
      const a = mine[0].address.startsWith("0x") ? mine[0].address : "0x" + mine[0].address;
      const ws = /^[0-9]+$/.test(workspace) ? workspace : "name:" + workspace;
      Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = "' + ws + '", follow = true, window = "address:' + a + '" })']);
      return true;
    }

    const at = visible.findIndex(t => t.activated);
    const target = visible[(at + 1) % visible.length];
    if (target.wayland)
      target.wayland.activate();
    return true;
  }
}
