import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.components.shared

// The workspace overview: every workspace side by side (the laptop one last), the windows on each,
// and the minimized ones below them. Search on the left. Opened by clicking the window title in the bar.
//
// Keys (in the search box): Up/Down select a window, Enter goes to it, Ctrl+D closes it, Ctrl+H hides or
// shows it, Ctrl+1..6 moves it to that workspace and Ctrl+` to the laptop one, Esc closes the overview.
// With the mouse: drag a window onto another workspace, or onto the minimized area of one; middle click
// a window to see what it looks like.
//
// The window, frame and focus rules live in FramedWindow; this file holds the overview itself.
Item {
  id: root

  property bool open: false
  property bool pinned: false
  property bool held: false             // stays open when it loses focus to a window it may coexist with
  property string currentWorkspace: ""     // the workspace this bar's monitor is showing
  property var focusedWindow: null         // the window that was focused: it is the one highlighted on opening

  signal closeRequested
  signal pinToggled

  // The Hyprland rule "qs-overview" in hyprland.lua must be this size plus the shadow (frame + 4).
  // It is kept short on purpose: the launcher opens at the bottom of the screen and must not be covered.
  readonly property real frameWidth: 1520
  readonly property real frameHeight: 372
  readonly property real sideWidth: 250

  // ---- the windows the overview knows about (never Quickshell's own) ----
  readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace && !Desktop.isShell(t))

  readonly property string query: search.text.trim().toLowerCase()

  function matches(t) {
    return String(t.title).toLowerCase().indexOf(query) !== -1 || Desktop.nameFor(t).toLowerCase().indexOf(query) !== -1 || Desktop.appId(t).toLowerCase().indexOf(query) !== -1;
  }

  // the windows that match the search, by address; null while the search is empty
  readonly property var matchSet: {
    if (query === "")
      return null;
    const set = {};
    for (const t of windows) {
      if (matches(t))
        set[t.address] = true;
    }
    return set;
  }

  // the order you gave the windows by dragging in the list (their addresses). Windows that are not in it
  // (new ones) come after, in the default order.
  property var customOrder: []

  // the default order: by workspace, minimized ones after the others, then by title
  function defaultSorted(list) {
    return list.slice().sort((a, b) => (Desktop.keys.indexOf(Desktop.homeKey(a)) - Desktop.keys.indexOf(Desktop.homeKey(b))) || (Number(Desktop.isHidden(a)) - Number(Desktop.isHidden(b))) || String(a.title).localeCompare(String(b.title)));
  }

  // every window in the order the list shows them (before the search narrows it down)
  readonly property var allRows: {
    const base = defaultSorted(windows);
    if (customOrder.length === 0)
      return base;
    const pos = {};
    customOrder.forEach((a, i) => pos[a] = i);
    const known = base.filter(t => pos[t.address] !== undefined).sort((a, b) => pos[a.address] - pos[b.address]);
    return known.concat(base.filter(t => pos[t.address] === undefined));
  }

  // the list on the left: the windows that match the search
  readonly property var rows: allRows.filter(t => query === "" || matches(t))

  // dropped on the list: the window goes in front of another one (insertBefore is its address), or last ("")
  function reorder(t, insertBefore) {
    const order = allRows.map(w => w.address).filter(a => a !== t.address);
    const at = insertBefore === "" ? order.length : order.indexOf(insertBefore);
    order.splice(at < 0 ? order.length : at, 0, t.address);
    customOrder = order;

    // the highlight stays with the window you moved
    Qt.callLater(() => selected = Math.max(0, rows.findIndex(w => w.address === t.address)));
  }

  property int selected: 0
  readonly property var selectedWindow: rows[selected]
  readonly property string selectedAddress: selectedWindow ? selectedWindow.address : ""

  onRowsChanged: selected = Math.max(0, Math.min(selected, rows.length - 1))

  function move(delta) {
    selected = Math.max(0, Math.min(rows.length - 1, selected + delta));
  }

  // ---- the window whose picture is showing (one at a time) ----
  property string previewAddress: ""

  function togglePreview(t) {
    previewAddress = previewAddress === t.address ? "" : t.address;
  }

  // ---- dragging a window onto a workspace, or onto the minimized area of one ----
  property var dragged: null               // the window being dragged
  property point dragAt: Qt.point(0, 0)    // where the pointer is, inside the frame
  property string dropWs: ""               // where it would land
  property string dropZone: ""
  property bool dragFromList: false        // it was pulled out of the list on the left (so it can be reordered there)
  property int dropIndex: -1               // in that list: the row it would go in front of (rows.length = last), or -1
  property int dropColIndex: -1            // in a workspace column: the row it would go in front of there

  // which workspace and which area (open or hidden) a point in the window is over, or null
  function targetAt(point) {
    for (let i = 0; i < columnRepeater.count; i++) {
      const col = columnRepeater.itemAt(i);
      if (!col)
        continue;
      const p = col.mapFromItem(null, point.x, point.y);
      if (p.x >= 0 && p.x <= col.width && p.y >= 0 && p.y <= col.height) {
        const zone = p.y < col.hiddenTop ? "open" : "hidden";
        return {
          ws: col.wsKey,
          zone: zone,
          index: col.insertIndexAt(zone, p),
          windows: col.windowsOf(zone)
        };
      }
    }
    return null;
  }

  // where in the list on the left a point is: the index of the row a window dropped there would go in
  // front of (rows.length = at the end), or -1 when the point is not over the list
  function listIndexAt(point) {
    const p = sideList.mapFromItem(null, point.x, point.y);
    if (p.x < 0 || p.x > sideList.width || p.y < 0 || p.y > sideList.height)
      return -1;
    const i = sideList.indexAt(p.x + sideList.contentX, p.y + sideList.contentY);
    if (i < 0)
      return rows.length;
    const item = sideList.itemAtIndex(i);
    const lower = item && (p.y + sideList.contentY - item.y) > item.height / 2;
    return lower ? i + 1 : i;
  }

  // y of the orange line that shows where a dragged window would go in the list
  function dropLineY() {
    if (rows.length === 0)
      return sideList.y;
    const last = dropIndex >= rows.length;
    const item = sideList.itemAtIndex(last ? rows.length - 1 : dropIndex);
    if (!item)
      return sideList.y;
    return sideList.y + item.y - sideList.contentY + (last ? item.height + 1 : -3);
  }

  // the window a dragged one goes in front of: the first one from index on that is not the dragged one
  // itself ("" = last)
  function beforeAddress(list, index, t) {
    for (let i = index; i < list.length; i++) {
      if (list[i].address !== t.address)
        return list[i].address;
    }
    return "";
  }

  function dragBegin(t, point, fromList) {
    dragged = t;
    dragFromList = fromList;
    dragMove(point);
  }

  function dragMove(point) {
    if (!dragged)
      return;
    const f = win.panel.mapFromItem(null, point.x, point.y);
    dragAt = Qt.point(f.x, f.y);
    const target = targetAt(point);
    dropWs = target ? target.ws : "";
    dropZone = target ? target.zone : "";
    dropIndex = (dragFromList && !target) ? listIndexAt(point) : -1;
    dropColIndex = target ? target.index : -1;
  }

  function dragEnd(point) {
    const t = dragged;
    const target = targetAt(point);
    const fromList = dragFromList;
    const index = fromList && !target ? listIndexAt(point) : -1;
    dragCancel();
    if (!t)
      return;

    // pulled out of the list and dropped back on it: that is a new order
    if (!target) {
      if (index >= 0)
        reorder(t, index < rows.length ? rows[index].address : "");
      return;
    }

    // dropped on a workspace: move it there if it is not there yet (visible or minimized), and put it
    // in front of the window it was dropped on
    const before = beforeAddress(target.windows, target.index, t);
    if (!(Desktop.homeKey(t) === target.ws && Desktop.isHidden(t) === (target.zone === "hidden")))
      Desktop.place(t, target.ws, target.zone === "hidden");
    reorder(t, before);
  }

  function dragCancel() {
    dragged = null;
    dropWs = "";
    dropZone = "";
    dropIndex = -1;
    dropColIndex = -1;
    dragFromList = false;
  }

  // after going to a window: close, unless the overview is pinned
  function finished() {
    if (!pinned)
      closeRequested();
  }

  onOpenChanged: {
    previewAddress = "";
    dragCancel();
    if (open) {
      search.text = "";
      const i = focusedWindow ? rows.findIndex(w => w.address === focusedWindow.address) : -1;
      selected = Math.max(0, i);
    }
  }

  // Ctrl+D close, Ctrl+H hide or show, Ctrl+1..6 move to a workspace, Ctrl+` move to the laptop one
  function handleKey(event) {
    if (!(event.modifiers & Qt.ControlModifier))
      return;

    const w = selectedWindow;
    if (!w)
      return;

    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
      const n = event.key - Qt.Key_0;
      if (n > Settings.workspaceCount)
        return;
      Desktop.moveToWorkspace(w, String(n));
    } else if (event.key === Qt.Key_QuoteLeft) {
      Desktop.moveToWorkspace(w, Settings.laptopWorkspace);
    } else if (event.key === Qt.Key_D) {
      Desktop.close(w);
    } else if (event.key === Qt.Key_H) {
      if (Desktop.isHidden(w))
        Desktop.show(w, false);
      else
        Desktop.hide(w);
    } else {
      return;
    }

    event.accepted = true;
  }

  FramedWindow {
    id: win
    windowTitle: "qs-overview"
    title: "Overview"
    open: root.open
    pinned: root.pinned
    held: root.held
    frameWidth: root.frameWidth
    frameHeight: root.frameHeight
    focusTarget: search               // the keyboard starts in the search box
    clickFocusesFrame: false
    onCloseRequested: root.closeRequested()
    onPinToggled: root.pinToggled()

    // ================= left: search and the list of windows =================
    Rectangle {
      id: searchBox
      x: 14
      y: 34
      width: root.sideWidth
      height: 34
      radius: Retro.corner
      color: Retro.inset
      border.color: search.activeFocus ? Theme.yellow : Theme.fgDim
      border.width: Retro.borderWidth

      Text {
        id: prompt
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
          leftMargin: 12
        }
        text: "/"
        color: Theme.yellow
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 1
      }

      Text {
        anchors {
          left: prompt.right
          verticalCenter: parent.verticalCenter
          leftMargin: 10
        }
        visible: search.text === ""
        text: "search windows"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize
      }

      TextInput {
        id: search
        anchors {
          left: prompt.right
          right: parent.right
          top: parent.top
          bottom: parent.bottom
          leftMargin: 10
          rightMargin: 12
        }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectByMouse: true
        clip: true
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize + 1

        onAccepted: {
          if (root.selectedWindow) {
            Desktop.focus(root.selectedWindow);
            root.finished();
          }
        }

        // pinned windows ignore Esc (use the x); otherwise it closes
        Keys.onEscapePressed: {
          if (!root.pinned)
            root.closeRequested();
        }
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onPressed: event => root.handleKey(event)
      }
    }

    ListView {
      id: sideList
      x: 14
      y: 74
      width: root.sideWidth
      height: root.frameHeight - 74 - 52
      clip: true
      spacing: 4
      boundsBehavior: Flickable.StopAtBounds
      model: ScriptModel {
        values: root.rows
      }
      currentIndex: root.selected
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

      delegate: WindowRow {
        required property var modelData
        required property int index
        toplevel: modelData
        width: ListView.view.width - 2
        selected: index === root.selected
        showWorkspace: true
        previewing: modelData.address === root.previewAddress
        onChosen: root.finished()
        onPreviewToggled: root.togglePreview(modelData)
        onDragStarted: point => root.dragBegin(modelData, point, true)
        onDragMoved: point => root.dragMove(point)
        onDragFinished: point => root.dragEnd(point)
        onDragCancelled: root.dragCancel()
      }

      Text {
        anchors.centerIn: parent
        visible: root.rows.length === 0
        text: root.query === "" ? "NO WINDOWS" : "NO MATCH"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }

    Text {
      x: 14
      y: root.frameHeight - 48
      width: root.sideWidth
      wrapMode: Text.WordWrap
      text: "↑↓ select  Enter go  Esc close\nCtrl+D close  Ctrl+H hide/show\nCtrl+1-6 move  middle: look  drag: sort"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 3
    }

    // ================= the workspaces, side by side =================
    Row {
      id: columns
      x: 14 + root.sideWidth + 12
      y: 34
      spacing: 8

      Repeater {
        id: columnRepeater
        model: Desktop.keys

        WorkspaceColumn {
          required property string modelData
          wsKey: modelData
          width: Math.floor((root.frameWidth - 14 - root.sideWidth - 12 - 14 - (Desktop.keys.length - 1) * 8) / Desktop.keys.length)
          height: root.frameHeight - 34 - 12
          windows: root.allRows
          matchSet: root.matchSet
          selectedAddress: root.selectedAddress
          previewAddress: root.previewAddress
          dropZone: root.dropWs === modelData ? root.dropZone : ""
          dropIndex: root.dropWs === modelData ? root.dropColIndex : -1
          current: modelData === root.currentWorkspace
          onSwitchRequested: {
            Desktop.gotoWorkspace(modelData);
            root.finished();
          }
          onWindowChosen: root.finished()
          onPreviewToggled: t => root.togglePreview(t)
          onDragStarted: (t, point) => root.dragBegin(t, point, false)
          onDragMoved: point => root.dragMove(point)
          onDragFinished: point => root.dragEnd(point)
          onDragCancelled: root.dragCancel()
        }
      }
    }

    // ================= while reordering the list: where the window would go =================
    Rectangle {
      x: sideList.x
      y: root.dropLineY()
      width: sideList.width - 2
      height: 3
      z: 90
      radius: 1
      color: Theme.orange
      visible: root.dragged !== null && root.dragFromList && root.dropIndex >= 0
    }

    // ================= the window being dragged, following the pointer =================
    Rectangle {
      id: ghost
      visible: root.dragged !== null
      z: 100
      width: 170
      height: 28
      x: root.dragAt.x - 24
      y: root.dragAt.y - height / 2
      radius: Retro.corner
      color: Theme.bgSel
      border.width: Retro.borderWidth
      border.color: Theme.orange
      opacity: 0.92

      Image {
        id: ghostIcon
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
          leftMargin: 6
        }
        width: 18
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
        fillMode: Image.PreserveAspectFit
        source: root.dragged && Desktop.hasIcon(root.dragged) ? Desktop.iconFor(root.dragged, false) : ""
        visible: source !== ""
      }

      Text {
        anchors.centerIn: ghostIcon
        visible: !ghostIcon.visible
        text: "水"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize
      }

      Text {
        anchors {
          left: ghostIcon.right
          right: parent.right
          verticalCenter: parent.verticalCenter
          leftMargin: 6
          rightMargin: 6
        }
        elide: Text.ElideRight
        text: root.dragged ? String(root.dragged.title) : ""
        color: Theme.fg
        font.family: Theme.fontSans
        font.pointSize: Theme.fontSize - 1
      }
    }
  }
}
