pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "lib/appicons.js" as AppIcons

// Workspaces and windows as the top bar and the overview see them: names, icons, and what you can do
// with a window (go to it, close, hide, show, move, show desktop).
// Quickshell's own windows (the launcher, the weather and quick windows ...) are never listed.
Singleton {
  id: root

  // after "move to workspace": go there together with the window (true) or stay where you are (false)
  readonly property bool followOnMove: true

  // ================= workspaces =================
  // "1" ... "6", then the laptop workspace: the order they are shown in
  readonly property var keys: Array.from({
    length: Settings.workspaceCount
  }, (_, i) => String(i + 1)).concat([Settings.laptopWorkspace])

  // what Hyprland wants for a workspace: "3" stays "3", "laptop" becomes "name:laptop"
  function selector(key) {
    return /^[0-9]+$/.test(key) ? key : "name:" + key;
  }

  // Used when settings.nix has no workspaceNames (or the list is too short), so the characters always show.
  readonly property var defaultNames: [
    {
      glyph: "一",
      reading: "Yī"
    },
    {
      glyph: "二",
      reading: "Èr"
    },
    {
      glyph: "三",
      reading: "Sān"
    },
    {
      glyph: "四",
      reading: "Sì"
    },
    {
      glyph: "五",
      reading: "Wǔ"
    },
    {
      glyph: "六",
      reading: "Liù"
    }
  ]

  // the laptop workspace: 水, with no reading
  readonly property var laptopName: Settings.laptopName || ({
    glyph: "水",
    reading: ""
  })

  function nameOf(key) {
    if (key === Settings.laptopWorkspace)
      return laptopName;
    const i = parseInt(key) - 1;
    return (Settings.workspaceNames || [])[i] || defaultNames[i];
  }

  // the character shown for a workspace: 一 for 1 ... and 水 for the laptop
  function glyph(key) {
    const n = nameOf(key);
    return n ? n.glyph : String(key);
  }

  // how it is read: Yī, Èr ... (nothing for the laptop)
  function reading(key) {
    const n = nameOf(key);
    return n ? n.reading : "";
  }

  // "1" ... "6", or "Laptop"
  function label(key) {
    return key === Settings.laptopWorkspace ? "Laptop" : String(key);
  }

  // the short name for a header: the reading, or the label where there is none
  function shortName(key) {
    return reading(key) !== "" ? reading(key) : label(key);
  }

  function gotoWorkspace(key) {
    dispatch('hl.dsp.focus({ workspace = "' + selector(key) + '" })');
  }

  // scrolling: -1 = the previous workspace, +1 = the next; wraps around the numbered ones.
  // From the laptop workspace it goes to the first (or the last) numbered one.
  function stepWorkspace(current, delta) {
    const count = Settings.workspaceCount;
    const n = parseInt(current);
    const target = isNaN(n) ? (delta > 0 ? 1 : count) : ((n - 1 + delta + count) % count) + 1;
    gotoWorkspace(String(target));
  }

  // ================= windows =================
  function isShell(t) {
    if (!t)
      return true;
    const id = appId(t);
    return id === "org.quickshell" || id === "quickshell" || String(t.title).startsWith("qs-");
  }

  function appId(t) {
    return t && t.wayland && t.wayland.appId ? t.wayland.appId : "";
  }

  // minimized windows live on a hidden workspace of their own: special:hidden_<workspace>
  function isHidden(t) {
    return !!(t && t.workspace && t.workspace.name.indexOf("hidden_") !== -1);
  }

  // the workspace a window belongs to (a minimized one belongs to where it was hidden from)
  function homeKey(t) {
    const n = t && t.workspace ? t.workspace.name : "";
    const m = /hidden_(.+)$/.exec(n);
    return m ? m[1] : n;
  }

  // how many windows belong to a workspace, minimized ones included
  function windowCount(key) {
    return Hyprland.toplevels.values.filter(t => t.workspace && homeKey(t) === key && !isShell(t)).length;
  }

  function byAddress(address) {
    return Hyprland.toplevels.values.find(t => t.address === address);
  }

  function entryFor(t) {
    const id = appId(t);
    return id !== "" ? DesktopEntries.heuristicLookup(id) : null;
  }

  // name / icon given in settings.nix (apps) for a window class or desktop id; null when there is none
  function override(id) {
    const lower = String(id || "").toLowerCase();
    if (lower === "")
      return null;
    const apps = Settings.apps || {};
    const entry = DesktopEntries.heuristicLookup(id);
    for (const key of Object.keys(apps)) {
      const app = apps[key];
      if (key.toLowerCase() === lower || (entry && entry.id === key) || (app.classes || []).some(c => c.toLowerCase() === lower))
        return app;
    }
    return null;
  }

  // the first of several ids (class, binary, player identity ...) that settings.nix knows
  function overrideAny(ids) {
    for (const id of ids) {
      const o = override(id);
      if (o)
        return o;
    }
    return null;
  }

  // the exact icon file app-icons.nix wrote into an overridden app's entry (color, never symbolic).
  // Asking the theme for the icon's name instead can land on the pack's symbolic folder, which accepts every size.
  function overrideIconFile(t) {
    const e = entryFor(t);
    return e && e.icon && String(e.icon).startsWith("/") ? "file://" + e.icon : "";
  }

  // the icon-pack icon for the bar's title box, for apps that ask for it with titleIcon = true in settings.nix
  function titleIcon(t) {
    const o = override(appId(t));
    if (!o || !o.titleIcon || !o.icon)
      return "";
    return overrideIconFile(t) || Quickshell.iconPath(o.icon, true) || "";
  }

  function nameFor(t) {
    const o = override(appId(t));
    if (o && o.name)
      return o.name;
    if (!t)
      return "";
    const renamed = AppIcons.names[appId(t).toLowerCase()];
    if (renamed)
      return renamed;
    const e = entryFor(t);
    if (e && e.name)
      return e.name;
    const id = appId(t);
    return id !== "" ? id : String(t.title);
  }

  // does the icon theme have an icon for this window's app at all?
  function hasIcon(t) {
    const o = override(appId(t));
    if (o && o.icon)
      return true;
    const e = entryFor(t);
    const name = AppIcons.iconByApp[appId(t).toLowerCase()] || (e && e.icon ? e.icon : appId(t));
    return name !== "" && Quickshell.iconPath(name, true) !== "";
  }

  // the one colour icon the theme has for a window's app, or "" (the bar then draws glyphFor)
  function symbolicIcon(t) {
    const e = entryFor(t);
    const name = AppIcons.iconByApp[appId(t).toLowerCase()] || (e && e.icon ? e.icon : appId(t));
    return name !== "" ? Quickshell.iconPath(name + "-symbolic", true) : "";
  }

  // a one colour character for the app (lib/appicons.js)
  function glyphFor(t) {
    const e = entryFor(t);
    const o = override(appId(t));
    if (o && o.glyph)
      return o.glyph;
    return AppIcons.glyph(appId(t), (e ? Array.from(e.categories || []) : []).concat(o ? (o.categories || []) : []));
  }

  // the icon of a window's app; with symbolic = true it prefers the symbolic version
  function iconFor(t, symbolic) {
    const o = override(appId(t));
    if (o && o.icon)
      return Quickshell.iconPath(o.icon, true) || Quickshell.iconPath("application-x-executable");
    const e = entryFor(t);
    const name = AppIcons.iconByApp[appId(t).toLowerCase()] || (e && e.icon ? e.icon : appId(t));

    if (symbolic && name !== "") {
      const s = Quickshell.iconPath(name + "-symbolic", true);
      if (s)
        return s;
    }

    return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable");
  }

  // ================= what you can do with a window =================
  function dispatch(code) {
    Quickshell.execDetached(["hyprctl", "dispatch", code]);
  }

  function addr(t) {
    return t.address.startsWith("0x") ? t.address : "0x" + t.address;
  }

  function moveTo(t, workspace, follow) {
    dispatch('hl.dsp.window.move({ workspace = "' + workspace + '", follow = ' + follow + ', window = "address:' + addr(t) + '" })');
  }

  function close(t) {
    if (t && t.wayland)
      t.wayland.close();
  }

  // hide = minimize: it goes to the hidden workspace of its own workspace
  function hide(t) {
    if (t && !isHidden(t))
      moveTo(t, "special:hidden_" + homeKey(t), false);
  }

  // show = bring a minimized window back to its workspace
  function show(t, follow) {
    if (t && isHidden(t))
      moveTo(t, selector(homeKey(t)), follow === true);
  }

  // dragging in the overview: put a window on a workspace, minimized or not, without going there
  function place(t, key, minimized) {
    if (!t)
      return;
    moveTo(t, minimized ? "special:hidden_" + key : selector(key), false);
  }

  // moves a window to another workspace; a minimized window stays minimized there
  function moveToWorkspace(t, key) {
    if (!t)
      return;
    if (isHidden(t))
      moveTo(t, "special:hidden_" + key, false);
    else
      moveTo(t, selector(key), followOnMove);
  }

  // go to a window: switch to its workspace (or bring it back first if it is minimized)
  property var pendingFocus: null

  function focus(t) {
    if (!t)
      return;
    if (isHidden(t)) {
      moveTo(t, selector(homeKey(t)), true);
      return;
    }
    gotoWorkspace(homeKey(t));
    pendingFocus = t;
    focusTimer.restart();
  }

  // the window is activated a moment after the workspace switch has happened
  Timer {
    id: focusTimer
    interval: 150
    onTriggered: {
      if (root.pendingFocus && root.pendingFocus.wayland)
        root.pendingFocus.wayland.activate();
      root.pendingFocus = null;
    }
  }

  // ================= show desktop =================
  // for each workspace: the windows that "show desktop" hid, so the next one can bring them back
  property var desktopMap: ({})

  function showingDesktop(ws) {
    return (desktopMap[ws] || []).length > 0;
  }

  function setDesktop(ws, list) {
    const m = Object.assign({}, desktopMap);
    if (list.length > 0)
      m[ws] = list;
    else
      delete m[ws];
    desktopMap = m;
  }

  // the first call hides every window of the workspace, the second brings them back
  function showDesktop(ws) {
    if (showingDesktop(ws)) {
      for (const a of desktopMap[ws]) {
        const t = byAddress(a);
        if (t && isHidden(t))
          moveTo(t, selector(ws), false);
      }
      setDesktop(ws, []);
      return;
    }

    const open = Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.name === ws && !isShell(t));
    if (open.length === 0)
      return;

    setDesktop(ws, open.map(t => t.address));
    for (const t of open)
      moveTo(t, "special:hidden_" + ws, false);
  }
}
