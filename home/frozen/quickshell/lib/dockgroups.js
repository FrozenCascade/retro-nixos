.pragma library

// Pure helpers for the dock: one button per app, however many windows it has.
// Windows are Hyprland toplevels; nothing here touches the compositor.

// "hidden_" workspaces are where minimized windows live
function isHidden(t) {
  return !!(t && t.workspace && t.workspace.name.indexOf("hidden_") !== -1);
}

// Windows of the same app (same app id) share an icon. A window with no app id stands alone.
//   order    the icon keys in the order the user dragged them (unknown icons come last)
//   state    { windowOrder: addresses, detached: addresses }
//            windowOrder = how the user ordered the windows of an app; detached = windows that got an icon of their own
//   perIcon  more windows than this overflow into another icon of the same app
// appIdOf is passed in so the caller's bindings keep tracking each window's app id.
// Every icon is { key, app, offset, detached, windows, appOrder }; appOrder is the addresses of all the
// app's shared windows, and this icon shows the slice starting at offset.
function group(windows, order, appIdOf, state, perIcon) {
  const detached = {};
  for (const a of state.detached)
    detached[a] = true;

  const rank = a => {
    const i = state.windowOrder.indexOf(a);
    return i < 0 ? state.windowOrder.length : i;
  };

  const apps = {};
  const appKeys = [];
  for (const t of windows) {
    const id = String(appIdOf(t) || "").toLowerCase();
    const app = id !== "" ? id : "window:" + t.address;

    if (!apps[app]) {
      apps[app] = [];
      appKeys.push(app);
    }
    apps[app].push(t);
  }

  const list = [];
  for (const app of appKeys) {
    const shared = apps[app].filter(t => !detached[t.address])
      .map((t, i) => ({ t: t, i: i }))
      .sort((a, b) => (rank(a.t.address) - rank(b.t.address)) || (a.i - b.i))
      .map(x => x.t);
    const appOrder = shared.map(t => t.address);

    for (let at = 0; at < shared.length; at += perIcon) {
      list.push({
        key: at === 0 ? app : app + "+" + (at / perIcon),
        app: app,
        offset: at,
        detached: false,
        windows: shared.slice(at, at + perIcon),
        appOrder: appOrder
      });
    }

    for (const t of apps[app]) {
      if (detached[t.address])
        list.push({ key: app + "#" + t.address, app: app, offset: 0, detached: true, windows: [t], appOrder: appOrder });
    }
  }

  const place = g => {
    const i = order.indexOf(g.key);
    return i < 0 ? order.length : i;
  };

  return list.map((g, i) => ({ g: g, i: i }))
    .sort((a, b) => (place(a.g) - place(b.g)) || (a.i - b.i))
    .map(x => x.g);
}

// The window a click should act on: the one focused most recently (history = addresses, newest first)
function lead(g, history) {
  for (const a of history) {
    for (const t of g.windows) {
      if (t.address === a)
        return t;
    }
  }
  return g.windows[0];
}

// The visible window `delta` steps from the focused one (wrapping): +1 = next, -1 = previous.
// With nothing focused in this icon, the first (or last) one.
function step(g, delta) {
  const visible = g.windows.filter(t => !isHidden(t));
  if (visible.length === 0)
    return null;

  const at = visible.findIndex(t => t.activated);
  if (at < 0)
    return delta > 0 ? visible[0] : visible[visible.length - 1];

  return visible[(at + delta + visible.length) % visible.length];
}

// The app's full window order after moving one window of this icon to a new place inside it; null if nothing changes
function reordered(g, address, targetIndex) {
  const from = g.windows.findIndex(t => t.address === address);
  if (from < 0)
    return null;

  const to = Math.max(0, Math.min(targetIndex, g.windows.length - 1));
  if (from === to)
    return null;

  const full = g.appOrder.slice();
  full.splice(g.offset + to, 0, full.splice(g.offset + from, 1)[0]);
  return full;
}
