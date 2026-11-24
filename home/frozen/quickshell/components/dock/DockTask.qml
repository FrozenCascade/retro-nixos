import QtQuick
import qs
import "../../lib/dockgroups.js" as Groups

// One running app in the dock. All windows of the app share this button, like KDE's icon-only task manager:
//   click          focus the last used window; click again to cycle through the app's windows
//                  (an app with a single window minimizes when it is already focused)
//   middle click   minimize or restore the last used window
//   right click    menu: every window of the app (drag to reorder, drag out for an icon of its own),
//                  then actions for the last used one
//   scroll         cycle through the app's windows
//   drag           reorder; drop an icon that was split off onto an icon of the same app to merge it back
//   hold + scroll over the launcher button: send the app's windows to the next / previous workspace
// The pips under the icon are the windows: the wide orange one is focused, hollow ones are minimized.
Item {
  id: task

  required property var host                 // the Dock
  required property var modelData            // { key, windows } from lib/dockgroups.js

  readonly property var group: modelData
  readonly property var lead: Groups.lead(group, host.focusHistory)
  readonly property bool isHidden: Groups.isHidden(lead)
  readonly property bool hovered: mouse.containsMouse
  readonly property bool focusedTask: group.windows.some(w => w.activated && !Groups.isHidden(w))

  readonly property int maxPips: 4

  width: host.buttonSize
  height: host.buttonSize
  z: hovered ? 1 : 0

  function activate() {
    const many = group.windows.length > 1;

    if (isHidden) {
      host.restoreWindow(lead);
    } else if (!focusedTask) {
      host.focusWindow(lead);
    } else if (many) {
      host.focusWindow(Groups.step(group, 1));
    } else {
      host.minimizeWindow(lead);
    }
  }

  function cycle(delta) {
    host.focusWindow(Groups.step(group, delta));
  }

  // Dropped at a place in the row: onto an icon of the same app a split-off window joins it again,
  // anywhere else the icon just moves there.
  function dropOn(targetIndex) {
    const target = host.groups[targetIndex];

    if (group.detached && target && target.app === group.app && target.key !== group.key)
      host.attachWindow(group.windows[0].address);
    else
      host.reorderTask(group.key, targetIndex);
  }

  Component.onDestruction: {
    if (host.dragTask === task)
      host.dragTask = null;

    if (host.hoverItem === task)
      host.hoverItem = null;

    if (host.menuTask === task)
      host.menuTask = null;

    if (mouse.pressed && mouse.leftGesture)
      host.draggingTask = false;
  }

  // raised-button shadow (always visible unless focused)
  Rectangle {
    x: 2
    y: 2
    width: parent.width
    height: parent.height
    radius: Retro.corner
    color: Retro.shadowColor
    visible: !task.focusedTask
  }

  // slot face: idle = flat, focused = selected
  Rectangle {
    anchors.fill: parent
    radius: Retro.corner
    color: task.focusedTask ? Theme.bgSel : Theme.bgAlt
  }

  Image {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 0 : -3

    width: task.host.iconSize
    height: task.host.iconSize

    sourceSize.width: task.host.iconSize * 2
    sourceSize.height: task.host.iconSize * 2

    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    source: task.host.iconFor(task.lead)

    // an app whose windows are all minimized looks faded
    opacity: task.group.windows.every(w => Groups.isHidden(w)) ? 0.45 : 1.0
  }

  // one pip per window
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - 9
    spacing: 3

    Repeater {
      model: task.group.windows.slice(0, task.maxPips)

      Rectangle {
        required property var modelData

        readonly property bool hidden: Groups.isHidden(modelData)
        readonly property bool focused: modelData.activated && !hidden

        width: focused ? 14 : 6
        height: 5
        radius: 1

        color: hidden ? "transparent" : (focused ? Theme.orange : Theme.fgDim)
        border.width: hidden ? 1 : 0
        border.color: Theme.fgDim
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    property real pressX: 0
    property bool moved: false
    property bool leftGesture: false
    property real wheelAccum: 0

    cursorShape: pressed && leftGesture && moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    onEntered: {
      task.host.hoverItem = task;
      task.host.showDock();
    }

    onExited: {
      if (task.host.hoverItem === task)
        task.host.hoverItem = null;
    }

    onPressed: event => {
      // Only left-button gestures can reorder.
      if (event.button === Qt.LeftButton) {
        pressX = event.x;
        moved = false;
        leftGesture = true;
        task.host.draggingTask = true;
        task.host.dragTask = task;
      }

      task.host.showDock();
    }

    onPositionChanged: event => {
      if (!pressed || !leftGesture || !(pressedButtons & Qt.LeftButton))
        return;
      if (Math.abs(event.x - pressX) >= task.host.reorderThreshold)
        moved = true;
    }

    onReleased: event => {
      if (event.button !== Qt.LeftButton)
        return;
      const wasMoved = moved;
      const key = task.group.key;

      // measured inside the row of tasks, so the launcher button doesn't shift the index
      const position = mouse.mapToItem(task.parent, event.x, event.y);
      const targetIndex = Math.floor(position.x / (task.host.buttonSize + task.host.itemSpacing));

      leftGesture = false;
      task.host.draggingTask = false;
      task.host.dragTask = null;

      // update the model after the input event finishes
      if (wasMoved)
        Qt.callLater(() => task.dropOn(targetIndex));

      if (!task.host.dockHovered)
        task.host.hideSoon();
    }

    onCanceled: {
      leftGesture = false;
      task.host.draggingTask = false;
      task.host.dragTask = null;
      moved = false;

      if (!task.host.dockHovered)
        task.host.hideSoon();
    }

    onClicked: event => {
      if (event.button === Qt.RightButton) {
        task.host.openMenu(task);
      } else if (event.button === Qt.MiddleButton) {
        if (task.isHidden)
          task.host.restoreWindow(task.lead);
        else
          task.host.minimizeWindow(task.lead);
      } else if (event.button === Qt.LeftButton && !moved) {
        task.activate();
      }
    }

    onWheel: wheel => {
      wheel.accepted = true;

      wheelAccum += wheel.angleDelta.y;
      if (Math.abs(wheelAccum) < 120)
        return;
      const delta = wheelAccum > 0 ? -1 : 1;  // up = backward
      wheelAccum = 0;

      if (!pressed) {
        task.cycle(delta);
        return;
      }

      // held down while scrolling over the launcher button: move the app's windows to another workspace
      const l = task.host.launcherButton;
      const p = mouse.mapToItem(l, wheel.x, wheel.y);
      if (p.x >= 0 && p.y >= 0 && p.x <= l.width && p.y <= l.height)
        task.host.sendGroup(task.group, delta);
    }
  }
}
