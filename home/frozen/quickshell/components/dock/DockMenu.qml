import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.components.shared

// The right-click menu of a dock button: a small retro window above the clicked icon.
// What it lists comes from Dock.buildActions(); an entry is { label, run, danger, current, dim } or { separator: true }.
// Entries with an `address` are the app's windows: drag one up or down to reorder, drag it out of the menu
// to give it an icon of its own.
Item {
  id: root

  required property var host                 // the Dock

  readonly property real menuWidth: 208
  readonly property real rowHeight: 28

  PopupWindow {
    id: menu
    visible: root.host.menuOpen
    color: "transparent"

    // Anchor to the top edge of the dock, above the clicked button.
    anchor.window: root.host
    anchor.rect.x: root.host.menuAnchorX
    anchor.rect.y: root.host.menuAnchorY
    anchor.rect.width: root.host.menuTask ? root.host.menuTask.width : 0
    anchor.rect.height: 1
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top

    implicitWidth: root.menuWidth + Retro.shadowOffset
    implicitHeight: frame.height + Retro.shadowOffset + 6   // + gap above the dock

    // hard drop shadow
    Rectangle {
      x: Retro.shadowOffset
      y: Retro.shadowOffset
      width: frame.width
      height: frame.height
      radius: Retro.corner
      color: Retro.shadowColor
    }

    Rectangle {
      id: frame
      width: root.menuWidth
      height: entries.y + entries.implicitHeight + 8

      radius: Retro.corner
      color: Theme.bg
      border.color: Theme.fg
      border.width: Retro.borderWidth

      // title bar: \\\ APP NAME
      TitleBar {
        title: root.host.menuTitle
        height: 22
        leftPad: 8
        showClose: false
      }

      // stripe under the title bar
      Row {
        x: 2
        y: 24
        width: parent.width - 4
        height: 3

        Repeater {
          model: root.host.stripeColors

          Rectangle {
            required property var modelData
            width: parent.width / 4
            height: 3
            color: modelData
          }
        }
      }

      Column {
        id: entries
        x: 6
        y: 33
        width: parent.width - 12
        spacing: 2

        Repeater {
          model: root.host.menuActions

          Rectangle {
            id: entry
            required property var modelData

            readonly property bool line: modelData.separator === true
            readonly property real textInset: modelData.current !== undefined ? 22 : 10
            readonly property bool draggable: modelData.address !== undefined

            z: entryMouse.dragging ? 5 : 0
            transform: Translate { y: entryMouse.dragging ? entryMouse.dragY : 0 }

            width: parent.width
            height: line ? 7 : root.rowHeight
            radius: Retro.corner

            // hover = the selected-row look from the launcher
            color: !line && (entryMouse.containsMouse || entryMouse.dragging) ? Theme.bgSel : "transparent"
            border.width: !line && (entryMouse.containsMouse || entryMouse.dragging) ? 2 : 0
            border.color: Theme.aqua

            // separator between the window list and the actions
            Rectangle {
              visible: entry.line
              anchors.centerIn: parent
              width: parent.width - 8
              height: 2
              color: Theme.fgDim
            }

            // marks the window that has the focus
            Rectangle {
              visible: entry.modelData.current === true
              anchors.verticalCenter: parent.verticalCenter
              x: 9
              width: 6
              height: 6
              color: Theme.orange
            }

            Text {
              visible: !entry.line
              anchors.verticalCenter: parent.verticalCenter
              x: entry.textInset
              width: parent.width - entry.textInset - 8
              elide: Text.ElideRight

              text: entry.modelData.label ?? ""
              opacity: entry.modelData.dim ? 0.55 : 1
              color: entry.modelData.danger ? Theme.red : Theme.fg
              font.family: Theme.fontSans
              font.bold: true
              font.pointSize: Theme.fontSize
            }

            MouseArea {
              id: entryMouse
              anchors.fill: parent
              enabled: !entry.line
              hoverEnabled: true

              property real pressY: 0
              property real dragX: 0
              property real dragY: 0
              property bool dragging: false

              // where the pointer is inside the list of entries (stays right while the entry follows it)
              function inList(e) {
                return mapToItem(entries, e.x, e.y);
              }

              onPressed: e => {
                pressY = inList(e).y;
                dragging = false;
                dragX = 0;
                dragY = 0;
              }

              onPositionChanged: e => {
                if (!pressed || !entry.draggable)
                  return;
                const p = inList(e);
                dragX = p.x - entries.width / 2;
                dragY = p.y - pressY;
                if (Math.abs(dragY) > 6 || Math.abs(dragX) > entries.width / 2)
                  dragging = true;
              }

              onReleased: e => {
                const wasDragging = dragging;
                const p = inList(e);
                dragging = false;

                if (!wasDragging) {
                  entry.modelData.run();
                  root.host.closeMenu();
                  return;
                }

                const g = root.host.menuTask.group;
                const address = entry.modelData.address;

                // outside the list: the window gets its own icon, inside: it moves to that row
                const away = p.x < -24 || p.x > entries.width + 24 || p.y < -40 || p.y > entries.height + 40;
                const row = Math.floor(p.y / (root.rowHeight + entries.spacing));

                Qt.callLater(() => away ? root.host.detachWindow(g, address) : root.host.moveInGroup(g, address, row));
              }

              onCanceled: dragging = false
            }
          }
        }
      }
    }
  }

  // Closes the menu when you click anywhere else.
  HyprlandFocusGrab {
    windows: [menu]
    active: root.host.menuOpen
    onCleared: root.host.closeMenu()
  }
}
