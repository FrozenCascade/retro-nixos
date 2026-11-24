import Quickshell.Wayland
import QtQuick
import qs
import qs.components.shared

// One window in the overview: icon and title.
//   click        go to the window
//   middle click show what the window looks like: the row stretches down to reveal a live picture
//   drag         pull it onto another workspace, or onto the minimized area of one (the overview does the drop)
// On hover (or when selected) buttons appear: a picture button, and in the search list also hide or show
// and move. Right click (search list) starts "move".
Item {
  id: row

  property var toplevel: null            // a Hyprland toplevel
  property bool selected: false          // the keyboard selection
  property bool dimmed: false            // does not match the search
  property bool showWorkspace: false     // show which workspace it is on (the search list does)
  property bool onlyClose: false         // workspace areas: no hide/show and move buttons, dragging does that
  property bool previewing: false        // stretched down to show the window

  signal chosen                          // it was clicked: the overview may close now
  signal previewToggled
  signal dragStarted(var point)          // the pointer pulled the row away (window coordinates)
  signal dragMoved(var point)
  signal dragFinished(var point)
  signal dragCancelled

  property bool moving: false            // the "move to" strip is showing
  property int chipsHovered: 0           // how many of its chips the pointer is on
  property bool pulled: false            // a drag is going on

  readonly property real headHeight: 28
  readonly property real previewHeight: Math.round((width - 12) * 9 / 16)

  readonly property bool hidden: toplevel ? Desktop.isHidden(toplevel) : false
  readonly property bool hasIcon: toplevel ? Desktop.hasIcon(toplevel) : false
  readonly property bool hot: rowMouse.containsMouse || actions.hovered || chipsHovered > 0
  readonly property bool showActions: (hot || selected) && !moving

  height: headHeight + (previewing ? previewHeight + 8 : 0)
  clip: true
  opacity: dimmed ? 0.4 : 1.0

  Behavior on height {
    NumberAnimation {
      duration: 140
      easing.type: Easing.OutCubic
    }
  }

  // if the row disappears in the middle of a drag, the drag is over
  Component.onDestruction: {
    if (pulled)
      dragCancelled();
  }

  // the "move to" strip goes away when the pointer has been off the row for a moment
  onHotChanged: {
    if (hot)
      cancelTimer.stop();
    else if (moving)
      cancelTimer.restart();
  }

  Timer {
    id: cancelTimer
    interval: 300
    onTriggered: row.moving = false
  }

  Rectangle {
    anchors.fill: parent
    radius: Retro.corner
    color: row.selected ? Theme.bgSel : Theme.bgAlt
    border.width: row.selected ? Retro.borderWidth : 0
    border.color: Theme.orange
  }

  // ================= the top line =================
  Item {
    id: head
    width: parent.width
    height: row.headHeight

    // the app's icon, or 水 when the icon theme has none
    Item {
      id: iconBox
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        leftMargin: 6
      }
      width: 18
      height: 18
      opacity: row.hidden ? 0.5 : 1.0

      Image {
        anchors.fill: parent
        sourceSize.width: 36
        sourceSize.height: 36
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        source: row.hasIcon ? Desktop.iconFor(row.toplevel, false) : ""
        visible: row.hasIcon
      }

      Text {
        anchors.centerIn: parent
        visible: !row.hasIcon
        text: "水"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize
      }
    }

    Text {
      anchors {
        left: iconBox.right
        right: row.showActions ? actions.left : (workspaceTag.visible ? workspaceTag.left : parent.right)
        verticalCenter: parent.verticalCenter
        leftMargin: 6
        rightMargin: 6
      }
      visible: !row.moving
      elide: Text.ElideRight
      text: row.toplevel ? String(row.toplevel.title) : ""
      color: row.hidden ? Theme.fgDim : Theme.fg
      font.family: Theme.fontSans
      font.pointSize: Theme.fontSize - 1
    }

    // which workspace (and whether minimized): the search list shows it
    Text {
      id: workspaceTag
      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
        rightMargin: 8
      }
      visible: row.showWorkspace && !row.showActions && !row.moving
      text: row.toplevel ? Desktop.glyph(Desktop.homeKey(row.toplevel)) + (row.hidden ? "  MIN" : "") : ""
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    // click: go to it. middle click: the picture. right click: move (search list). Pull: drag.
    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

      // lists scroll with the wheel; a drag here must not turn into a flick
      preventStealing: true

      property point pressAt: Qt.point(0, 0)

      onPressed: mouse => {
        pressAt = Qt.point(mouse.x, mouse.y);
        row.pulled = false;
      }

      onPositionChanged: mouse => {
        if (!pressed || !(pressedButtons & Qt.LeftButton))
          return;
        if (!row.pulled && Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y) > 10) {
          row.pulled = true;
          row.dragStarted(mapToItem(null, mouse.x, mouse.y));
        }
        if (row.pulled)
          row.dragMoved(mapToItem(null, mouse.x, mouse.y));
      }

      onReleased: mouse => {
        if (row.pulled)
          row.dragFinished(mapToItem(null, mouse.x, mouse.y));
      }

      onClicked: mouse => {
        // the end of a drag is not a click
        if (row.pulled) {
          row.pulled = false;
          return;
        }

        if (mouse.button === Qt.MiddleButton) {
          row.previewToggled();
        } else if (mouse.button === Qt.RightButton) {
          if (!row.onlyClose)
            row.moving = true;
        } else {
          Desktop.focus(row.toplevel);
          row.chosen();
        }
      }
    }

    // ---- the buttons ----
    Row {
      id: actions
      visible: row.showActions
      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
        rightMargin: 4
      }
      spacing: 3

      readonly property bool hovered: previewButton.hovered || hideButton.hovered || moveButton.hovered || closeButton.hovered

      MiniButton {
        id: previewButton
        padX: 4
        text: "\uf03e"                                // a picture
        active: row.previewing
        onClicked: row.previewToggled()
      }

      MiniButton {
        id: hideButton
        visible: !row.onlyClose
        padX: 4
        text: row.hidden ? "\uf06e" : "\uf070"        // an eye (show) or an eye with a line through it (hide)
        onClicked: row.hidden ? Desktop.show(row.toplevel, false) : Desktop.hide(row.toplevel)
      }

      MiniButton {
        id: moveButton
        visible: !row.onlyClose
        padX: 4
        text: "\uf0b2"                                // arrows
        onClicked: row.moving = true
      }

      MiniButton {
        id: closeButton
        padX: 4
        text: "\uf00d"                                // x
        danger: true
        onClicked: Desktop.close(row.toplevel)
      }
    }

    // ---- "move to": one small button per workspace ----
    Row {
      visible: row.moving
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        leftMargin: 6
      }
      spacing: 2

      Repeater {
        model: Desktop.keys

        Rectangle {
          id: chip
          required property string modelData

          readonly property bool here: row.toplevel ? modelData === Desktop.homeKey(row.toplevel) : false

          width: 20
          height: 20
          radius: Retro.corner
          color: chipMouse.containsMouse ? Theme.bgSel : Theme.bgAlt
          border.width: Retro.borderWidth
          border.color: chip.here ? Theme.orange : Theme.fgDim

          Text {
            anchors.centerIn: parent
            text: Desktop.glyph(chip.modelData)
            color: chip.here ? Theme.orange : Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: row.chipsHovered += containsMouse ? 1 : -1
            onClicked: {
              Desktop.moveToWorkspace(row.toplevel, chip.modelData);
              row.moving = false;
            }
          }
        }
      }
    }
  }

  // ================= the picture, below the top line =================
  Item {
    id: preview
    x: 6
    y: row.headHeight + 2
    width: parent.width - 12
    height: row.previewHeight
    visible: row.previewing

    Rectangle {
      anchors.fill: parent
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: Theme.fgDim
    }

    // a live picture of the window (only while the row is stretched open)
    Loader {
      id: shot
      anchors.centerIn: parent
      active: row.previewing && !row.hidden && row.toplevel !== null && row.toplevel.wayland !== null

      sourceComponent: ScreencopyView {
        captureSource: row.toplevel.wayland
        live: true
        constraintSize: Qt.size(preview.width - 6, preview.height - 6)
      }
    }

    // no picture (minimized, or the window can't be captured): 水
    Column {
      anchors.centerIn: parent
      visible: !(shot.item && shot.item.hasContent)
      spacing: 2

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "水"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 8
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: row.hidden ? "MINIMIZED" : "NO PICTURE"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 3
      }
    }
  }
}
