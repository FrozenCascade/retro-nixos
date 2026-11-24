import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs
import qs.components.shared
import "../../lib/appicons.js" as AppIcons
import "../../lib/dockgroups.js" as Groups

PanelWindow {
  id: dock

  required property var modelData
  screen: modelData

  // ---- sizing (icon sizes unchanged) ----
  readonly property real iconSize: 64
  readonly property real buttonSize: 72
  readonly property real dockHeight: 90
  readonly property real horizontalPadding: 10
  readonly property real itemSpacing: 4
  readonly property real bottomGap: 10
  readonly property real revealHeight: 4
  readonly property real reorderThreshold: 10
  readonly property int maxTasks: 10                       // the dock shows this many windows; more can be scrolled into view by dragging
  readonly property real maxTasksWidth: maxTasks * buttonSize + (maxTasks - 1) * itemSpacing + 2

  // ---- retro look ----
  readonly property var stripeColors: [Theme.green, Theme.blue, Theme.orange, Theme.red]

  // true = you travel with a window you scroll on, false = it leaves silently
  readonly property bool wheelFollowsWindow: true

  readonly property var monitor: Hyprland.monitorFor(modelData)

  readonly property string wsName: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : ""

  // Custom presentation order: app keys, as dragged (see lib/dockgroups.js).
  property var taskOrder: []


  // ---- windows and groups ----
  // Real top-level windows on this workspace, including minimized ones. Menus and tooltips (no Wayland
  // handle) and dialogs (they report a parent window) never get a button.
  readonly property var windows: Hyprland.toplevels.values.filter(t =>
    !Desktop.isShell(t) &&
    t.wayland && !t.wayland.parent &&
    t.workspace &&
    wsName !== "" &&
    (
      t.workspace.name === wsName ||
      t.workspace.name.endsWith("hidden_" + wsName)
    )
  )

  // ---- grouping (rules live in lib/dockgroups.js) ----
  readonly property int windowsPerIcon: 4              // an app with more windows gets another icon
  property var windowOrder: []                         // window addresses: how the windows of an app were ordered in the menu
  property var detached: []                            // window addresses that have an icon of their own

  // One entry per icon, see Groups.group(). taskOrder (the icon keys, as dragged) decides their order.
  readonly property var groups: Groups.group(windows, taskOrder, appId, { windowOrder: windowOrder, detached: detached }, windowsPerIcon)

  // The button being dragged right now (scrolling over the launcher button then moves its windows)
  property var dragTask: null
  property alias launcherButton: launcherBtn

  // Window addresses, the most recently focused first. A button acts on the first of its windows in this list.
  property var focusHistory: []
  readonly property var activeWin: Hyprland.toplevels.values.find(t => t.activated) || null

  onActiveWinChanged: {
    if (!activeWin)
      return;
    const a = activeWin.address;
    focusHistory = [a].concat(focusHistory.filter(x => x !== a)).slice(0, 40);
  }


  property bool shown: false
  property var hoverItem: null
  property bool draggingTask: false
  property bool manuallyHidden: false
  property bool revealArmed: false
  onManuallyHiddenChanged: LauncherState.dockHidden = manuallyHidden

  function forceHideDock() {
    if (LauncherState.pinned)
      return;
    manuallyHidden = true;

    // Require a fresh entry into the reveal strip.
    revealArmed = !zoneHover.hovered;

    hideTimer.stop();
    menuCloseTimer.stop();

    menuTask = null;
    hoverItem = null;
    draggingTask = false;
    shown = false;
  }

  // ---- right-click menu state ----
  property var menuTask: null                        // the dock button the menu is open for
  readonly property bool menuOpen: menuTask !== null
  readonly property var menuActions: menuTask ? buildActions(menuTask) : []
  readonly property string menuTitle: menuTask ? nameFor(menuTask.lead) : ""

  // where the menu attaches: the top edge of the dock, over the clicked button
  readonly property real menuAnchorX: menuTask ? bg.x + row.x + taskFlick.x - taskFlick.contentX + taskRow.x + menuTask.x : 0
  readonly property real menuAnchorY: bg.y


  readonly property bool dockHovered: zoneHover.hovered || hoverItem !== null || draggingTask || menuOpen || LauncherState.open

  onDockHoveredChanged: {
    if (dockHovered) {
      showDock();
    } else {
      hideTimer.restart();
    }
  }

  function showDock() {
    if (manuallyHidden)
      return;
    hideTimer.stop();
    shown = true;
  }

  function openMenu(task) {
    menuTask = (menuTask === task) ? null : task;
    showDock();
  }

  function closeMenu() {
    menuTask = null;
    hoverItem = null;        // the popup grab can swallow the icon's "exited" event
    menuCloseTimer.restart();
  }

  function hideSoon() {
    hideTimer.restart();
  }

  // ---- launcher button ----
  function openLauncher() {
    Quickshell.execDetached(["qs", "ipc", "call", "launcher", "toggle"]);
  }

  // Tries a few common names for the NixOS logo in your icon theme.
  function launcherIcon() {
    const names = ["nix-snowflake", "distributor-logo-nixos", "nixos", "start-here"];

    for (const n of names) {
      const p = Quickshell.iconPath(n, true);
      if (p)
        return p;
    }

    return Quickshell.iconPath("application-x-executable");
  }

  // ---- workspace scrolling ----
  // Neighbouring numbered workspace (wrapping) of the one shown on this monitor.
  // Returns -1 on the laptop workspace, which stays out of the cycle.
  function neighbourWorkspace(delta) {
    const n = parseInt(dock.wsName);
    const count = Settings.workspaceCount;

    if (isNaN(n) || n < 1 || n > count)
      return -1;

    return ((n - 1 + delta + count) % count) + 1;
  }

  // Launcher icon: switch the workspace itself
  function switchWorkspace(delta) {
    const target = neighbourWorkspace(delta);

    if (target < 0)
      return;
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "' + target + '" })']);
  }


  // App button: send all of the app's visible windows to the next/previous workspace
  function sendGroup(g, delta) {
    const target = neighbourWorkspace(delta);

    if (target < 0)
      return;
    g.windows.filter(w => !Groups.isHidden(w)).forEach((w, i) => moveWindow(w, String(target), wheelFollowsWindow && i === 0));
  }

  // ---- windows inside an app ----
  function liveAddresses() {
    return Hyprland.toplevels.values.map(t => t.address);
  }

  // Put one icon's windows in a new order (drag them in the right-click menu)
  function moveInGroup(g, address, targetIndex) {
    const full = Groups.reordered(g, address, targetIndex);
    if (!full)
      return;

    const live = liveAddresses();
    windowOrder = windowOrder.filter(a => full.indexOf(a) < 0 && live.indexOf(a) >= 0).concat(full);
  }

  // Give a window an icon of its own, right after the icon it came from
  function detachWindow(g, address) {
    if (g.detached || g.windows.length < 2)
      return;

    const keys = groups.map(x => x.key);
    keys.splice(keys.indexOf(g.key) + 1, 0, g.app + "#" + address);
    taskOrder = keys;

    const live = liveAddresses();
    detached = detached.filter(a => live.indexOf(a) >= 0).concat(address);
  }

  // Put it back with the rest of its app
  function attachWindow(address) {
    detached = detached.filter(a => a !== address);
  }

  // ---- ordering ----
  function reorderTask(key, targetIndex) {
    const ordered = dock.groups.map(g => g.key);
    const fromIndex = ordered.indexOf(key);

    if (fromIndex < 0 || ordered.length < 2)
      return;
    targetIndex = Math.max(0, Math.min(targetIndex, ordered.length - 1));

    if (fromIndex === targetIndex)
      return;
    ordered.splice(targetIndex, 0, ordered.splice(fromIndex, 1)[0]);

    dock.taskOrder = ordered;
  }


  // ---- helpers ----
  function appId(t) {
    if (!t)
      return "";

    return t.wayland && t.wayland.appId ? t.wayland.appId : "";
  }

  function entryFor(t) {
    const id = appId(t);
    return id !== "" ? DesktopEntries.heuristicLookup(id) : null;
  }

  function iconFor(t) {
    const o = Desktop.override(appId(t));
    if (o && o.icon)
      return Desktop.overrideIconFile(t) || Quickshell.iconPath(o.icon, true) || Quickshell.iconPath("application-x-executable");
    const e = entryFor(t);
    const name = AppIcons.iconByApp[appId(t).toLowerCase()] || (e && e.icon ? e.icon : appId(t));

    return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable");
  }

  function nameFor(t) {
    const o = Desktop.override(appId(t));
    if (o && o.name)
      return o.name;
    if (!t)
      return "";

    const e = entryFor(t);
    if (e && e.name)
      return e.name;

    const id = appId(t);
    return id !== "" ? id : t.title;
  }

  function moveWindow(t, workspace, follow) {
    const a = t.address.startsWith("0x") ? t.address : "0x" + t.address;

    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = "' + workspace + '", follow = ' + follow + ', window = "address:' + a + '" })']);
  }

  function restoreWindow(t) {
    const ws = dock.wsName;
    dock.moveWindow(t, /^[0-9]+$/.test(ws) ? ws : "name:" + ws, true);
  }

  function minimizeWindow(t) {
    dock.moveWindow(t, "special:hidden_" + dock.wsName, false);
  }

  function focusWindow(t) {
    if (t && t.wayland)
      t.wayland.activate();
  }

  function dispatchWindow(t, call) {
    const a = t.address.startsWith("0x") ? t.address : "0x" + t.address;
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window." + call.replace("%", 'window = "address:' + a + '"')]);
  }

  // Menu entries: add, remove, or reorder items here.
  // An app with several windows lists them first; the actions below apply to its last used window.
  function buildActions(task) {
    const w = task.lead;
    const items = [];

    if (task.group.windows.length > 1) {
      for (const x of task.group.windows) {
        items.push({
          address: x.address,
          label: x.title || nameFor(x),
          current: x.activated && !Groups.isHidden(x),
          dim: Groups.isHidden(x),
          run: () => Groups.isHidden(x) ? restoreWindow(x) : focusWindow(x)
        });
      }
      items.push({ separator: true });
    }

    // Maximize and fullscreen only make sense for visible windows
    if (!task.isHidden)
      items.push({ label: "Maximize", run: () => dispatchWindow(w, 'fullscreen({ mode = "maximized", action = "toggle", % })') });

    items.push({
      label: task.isHidden ? "Restore" : "Minimize",
      run: () => task.isHidden ? restoreWindow(w) : minimizeWindow(w)
    });

    if (!task.isHidden)
      items.push({ label: "Fullscreen", run: () => dispatchWindow(w, 'fullscreen({ mode = "fullscreen", action = "toggle", % })') });

    items.push({ label: "Floating", run: () => dispatchWindow(w, 'float({ action = "toggle", % })') });

    items.push({
      label: task.group.windows.length > 1 ? "Close this window" : "Close",
      danger: true,
      run: () => w.wayland && w.wayland.close()
    });

    if (task.group.windows.length > 1) {
      items.push({
        label: "Close all",
        danger: true,
        run: () => task.group.windows.forEach(x => x.wayland && x.wayland.close())
      });
    }

    return items;
  }

  // ---- window setup ----
  anchors.bottom: true

  // Place the dock above fullscreen windows.
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "dock"

  // extra width leaves room for the drop shadow on the right
  implicitWidth: Math.max(row.implicitWidth + horizontalPadding * 2 + Retro.shadowOffset * 2, 100)
  implicitHeight: dockHeight + bottomGap

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  // Always present: the launcher button needs the dock even with no windows open.
  visible: true

  // Only the reveal strip / visible dock receives input.
  mask: Region {
    item: zone
  }


  Item {
    id: content
    anchors.fill: parent

    // ---- dock hover detection ----
    Item {
      id: zone
      z: 10

      x: bg.x
      width: bg.width + Retro.shadowOffset
      anchors.bottom: parent.bottom

      height: dock.shown ? bg.height + dock.bottomGap : dock.revealHeight

      HoverHandler {
        id: zoneHover
        blocking: false

        onHoveredChanged: {
          if (!hovered) {
            if (dock.manuallyHidden)
              dock.revealArmed = true;

            return;
          }

          // A fresh hover restores normal dock behavior.
          if (dock.manuallyHidden && dock.revealArmed) {
            dock.manuallyHidden = false;
            dock.revealArmed = false;
            dock.showDock();
          }
        }
      }
    }

    Timer {
      id: hideTimer
      interval: 300
      repeat: false

      onTriggered: {
        if (!dock.dockHovered) {
          dock.hoverItem = null;
          dock.shown = false;
        }
      }
    }

    Timer {
      id: menuCloseTimer
      interval: 150
      repeat: false
      onTriggered: dock.shown = false
    }

    // ---- dock frame ----
    Rectangle {
      id: bg

      width: row.implicitWidth + dock.horizontalPadding * 2
      height: dock.dockHeight
      anchors.horizontalCenter: parent.horizontalCenter

      radius: Retro.corner
      color: Theme.bg
      border.color: Theme.fg
      border.width: Retro.borderWidth

      y: dock.shown ? content.height - height - dock.bottomGap : content.height

      Behavior on y {
        NumberAnimation {
          duration: 160
          easing.type: Easing.OutCubic
        }
      }

      // hard drop shadow (drawn behind the frame)
      Rectangle {
        z: -1
        x: Retro.shadowOffset
        y: Retro.shadowOffset
        width: parent.width
        height: parent.height
        radius: Retro.corner
        color: Retro.shadowColor
      }

      Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        spacing: dock.itemSpacing

        DockLauncherButton {
          id: launcherBtn
          host: dock
        }


        // ---- separator (only when apps are open) ----
        Item {
          visible: dock.windows.length > 0
          width: 13
          height: dock.buttonSize

          Rectangle {
            anchors.centerIn: parent
            width: 2
            height: dock.buttonSize * 0.65
            color: Theme.fgDim
          }
        }

        // ---- running apps: at most maxTasks buttons wide. With more, drag here to scroll them (the launcher
        // button and the separator stay where they are). ----
        Flickable {
          id: taskFlick
          visible: dock.windows.length > 0
          width: Math.min(taskRow.implicitWidth + 2, dock.maxTasksWidth)
          height: dock.buttonSize + 2
          contentWidth: taskRow.implicitWidth + 2
          contentHeight: height
          clip: true
          interactive: contentWidth > width
          flickableDirection: Flickable.HorizontalFlick
          boundsBehavior: Flickable.StopAtBounds

          Row {
            id: taskRow
            spacing: dock.itemSpacing

            Repeater {
              model: dock.groups

              DockTask {
                host: dock
              }
            }
          }
        }
      }
    }

    DockMenu {
      host: dock
    }
  }
}
