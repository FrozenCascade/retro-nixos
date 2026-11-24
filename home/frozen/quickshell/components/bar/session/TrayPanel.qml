import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs
import qs.components.shared
import qs.components.bar.calendar

// Status apps (the tray). Click one to open it, right-click for its menu. MANAGE lists them all with
// open / menu / hide / quit buttons; hidden ones stay out of the normal view until you show them again.
// QUIT presses the app's own Quit / Exit menu entry, or kills it by name when it has none.
Item {
  id: panel

  property var window: null             // the Session window, which menus open relative to
  property bool manage: false

  readonly property var all: SystemTray.items.values
  readonly property var shown: all.filter(i => !SessionState.isHidden(i.id))

  // edit here: status apps that never get a QUIT button (matched against id and title)
  readonly property var protectedApps: /network|nm-applet|blueman|bluetooth/i

  implicitHeight: col.implicitHeight
  height: implicitHeight

  function openMenu(item, x, y) {
    if (item.hasMenu)
      item.display(panel.window, x, y);
  }

  Column {
    id: col
    width: panel.width
    spacing: 8

    Item {
      width: parent.width
      height: 24

      SectionHead {
        anchors { left: parent.left; right: manageBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: "STATUS APPS (" + panel.shown.length + ")"
      }

      MiniButton {
        id: manageBtn
        anchors.right: parent.right
        text: "MANAGE"
        active: panel.manage
        onClicked: panel.manage = !panel.manage
      }
    }

    Text {
      visible: panel.all.length === 0
      text: "NO STATUS APPS RUNNING"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }

    Flow {
      width: parent.width
      spacing: 6
      visible: !panel.manage

      Repeater {
        model: panel.shown
        delegate: Item {
          id: tile
          required property var modelData
          width: 36
          height: 32

          Rectangle {
            x: 2
            y: 2
            width: 34
            height: 30
            radius: Retro.corner
            color: Retro.shadowColor
            visible: !tileMouse.pressed
          }

          Rectangle {
            x: tileMouse.pressed ? 2 : 0
            y: tileMouse.pressed ? 2 : 0
            width: 34
            height: 30
            radius: Retro.corner
            color: tileMouse.containsMouse ? Theme.bgSel : Theme.bgAlt

            Image {
              anchors.centerIn: parent
              width: 18
              height: 18
              sourceSize: Qt.size(18, 18)
              fillMode: Image.PreserveAspectFit
              source: tile.modelData.icon
            }
          }

          MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) {
                const p = tile.mapToItem(null, mouse.x, mouse.y);
                panel.openMenu(tile.modelData, p.x, p.y);
              } else {
                tile.modelData.activate();
              }
            }
          }
        }
      }
    }

    Repeater {
      model: panel.manage ? panel.all : []
      delegate: Rectangle {
        id: row
        required property var modelData
        readonly property bool hidden: SessionState.isHidden(modelData.id)
        readonly property string label: String(modelData.title || modelData.id)
        readonly property bool canQuit: !panel.protectedApps.test(modelData.id + " " + label)

        // reads the app's menu so QUIT can find its own Quit entry
        QsMenuOpener { id: opener; menu: row.modelData.menu }
        Process { id: killer }

        function quit() {
          const entries = opener.children ? opener.children.values : [];
          for (const e of entries) {
            if (!e.isSeparator && /^(quit|exit)/i.test((e.text || "").replace(/&/g, ""))) {
              e.triggered();
              return;
            }
          }
          killer.command = ["pkill", "-fi", label];
          killer.running = true;
        }

        width: col.width
        height: 32
        radius: Retro.corner
        color: Retro.inset
        opacity: hidden ? 0.55 : 1

        Image {
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          width: 20
          height: 20
          sourceSize: Qt.size(20, 20)
          fillMode: Image.PreserveAspectFit
          source: row.modelData.icon
        }

        Text {
          x: 38
          width: parent.width - 38 - 240
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: (row.modelData.title || row.modelData.id).toUpperCase()
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        Row {
          anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
          spacing: 4
          MiniButton { text: "OPEN"; onClicked: row.modelData.activate() }
          MiniButton {
            text: "MENU"
            visible: row.modelData.hasMenu
            onClicked: {
              const p = row.mapToItem(null, row.width - 100, row.height);
              panel.openMenu(row.modelData, p.x, p.y);
            }
          }
          MiniButton {
            text: row.hidden ? "SHOW" : "HIDE"
            active: row.hidden
            onClicked: SessionState.setHidden(row.modelData.id, !row.hidden)
          }
          MiniButton { text: "QUIT"; visible: row.canQuit; onClicked: row.quit() }
        }
      }
    }
  }
}
