import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// The area selector for screenshots and recordings (state and answers: RegionPicker.qml). One window per
// monitor, made only while a selection is going on, dimming the screen over everything.
//   drag on empty space   draw a new area         drag inside   move it
//   drag an edge/corner   resize it               arrows        nudge by 1 px (Shift: 10)
//   Enter or double click confirm                 Esc cancel; right click clears the area (cancels if there is none)
// The screen stays live underneath (it is not a frozen picture), and the window is gone before the
// capture starts.
Scope {
  id: root

  required property var modelData            // the monitor this window covers

  LazyLoader {
    active: RegionPicker.active

    PanelWindow {
      id: win

      // ---- settings (edit here) ----
      readonly property real dimOpacity: 0.5
      readonly property int grab: 9             // how close to an edge counts as holding it, in pixels
      readonly property int handleSize: 9

      // what a press grabs (bit flags, so a corner is two edges)
      readonly property int gLeft: 1
      readonly property int gRight: 2
      readonly property int gTop: 4
      readonly property int gBottom: 8
      readonly property int gIn: 16
      readonly property int gNew: 32           // drawing a new area

      screen: root.modelData
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "qs-region"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      // the selection in this window's own coordinates (empty when it is on another monitor)
      readonly property bool mine: RegionPicker.hasSel && RegionPicker.screenName === root.modelData.name
      readonly property real sx: mine ? RegionPicker.selX - root.modelData.x : 0
      readonly property real sy: mine ? RegionPicker.selY - root.modelData.y : 0
      readonly property real sw: mine ? RegionPicker.selW : 0
      readonly property real sh: mine ? RegionPicker.selH : 0

      function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
      }

      // which part of the selection a pointer at (x, y) would take hold of; 0 = none
      function gripAt(x, y) {
        if (!mine)
          return 0;
        if (x < sx - grab || x > sx + sw + grab || y < sy - grab || y > sy + sh + grab)
          return 0;
        let g = 0;
        if (Math.abs(x - sx) <= grab)
          g |= gLeft;
        else if (Math.abs(x - (sx + sw)) <= grab)
          g |= gRight;
        if (Math.abs(y - sy) <= grab)
          g |= gTop;
        else if (Math.abs(y - (sy + sh)) <= grab)
          g |= gBottom;
        return g !== 0 ? g : gIn;
      }

      function cursorFor(g) {
        switch (g) {
        case gLeft:
        case gRight:
          return Qt.SizeHorCursor;
        case gTop:
        case gBottom:
          return Qt.SizeVerCursor;
        case gLeft | gTop:
        case gRight | gBottom:
          return Qt.SizeFDiagCursor;
        case gRight | gTop:
        case gLeft | gBottom:
          return Qt.SizeBDiagCursor;
        case gIn:
          return Qt.SizeAllCursor;
        default:
          return Qt.CrossCursor;
        }
      }

      // write a rectangle (this window's coordinates) back to the shared selection
      function put(l, t, r, b) {
        RegionPicker.setSel(root.modelData.name, Math.round(root.modelData.x + l), Math.round(root.modelData.y + t),
                            Math.round(r - l), Math.round(b - t));
      }

      // the pointer has moved (dx, dy) since the press; `from` is the selection when it was pressed
      function dragBy(kind, from, px, py, dx, dy) {
        const min = RegionPicker.minSize;
        if (kind === gNew) {
          put(clamp(Math.min(from.ox, px), 0, width), clamp(Math.min(from.oy, py), 0, height),
              clamp(Math.max(from.ox, px), 0, width), clamp(Math.max(from.oy, py), 0, height));
        } else if (kind === gIn) {
          const nx = clamp(from.x + dx, 0, width - from.w);
          const ny = clamp(from.y + dy, 0, height - from.h);
          put(nx, ny, nx + from.w, ny + from.h);
        } else {
          let l = from.x, t = from.y, r = from.x + from.w, b = from.y + from.h;
          if (kind & gLeft)
            l = clamp(from.x + dx, 0, r - min);
          if (kind & gRight)
            r = clamp(r + dx, l + min, width);
          if (kind & gTop)
            t = clamp(from.y + dy, 0, b - min);
          if (kind & gBottom)
            b = clamp(b + dy, t + min, height);
          put(l, t, r, b);
        }
      }

      function nudge(dx, dy) {
        if (!mine)
          return;
        const x = clamp(sx + dx, 0, width - sw);
        const y = clamp(sy + dy, 0, height - sh);
        put(x, y, x + sw, y + sh);
      }

      // ---- the dimming: four panels around the selection (the whole screen when there is none) ----
      Rectangle {
        x: 0
        y: 0
        width: win.width
        height: win.sy
        color: Qt.rgba(0, 0, 0, win.dimOpacity)
      }

      Rectangle {
        x: 0
        y: win.sy + win.sh
        width: win.width
        height: win.height - (win.sy + win.sh)
        color: Qt.rgba(0, 0, 0, win.dimOpacity)
      }

      Rectangle {
        x: 0
        y: win.sy
        width: win.sx
        height: win.sh
        color: Qt.rgba(0, 0, 0, win.dimOpacity)
      }

      Rectangle {
        x: win.sx + win.sw
        y: win.sy
        width: win.width - (win.sx + win.sw)
        height: win.sh
        color: Qt.rgba(0, 0, 0, win.dimOpacity)
      }

      // ---- the selection: an outline, eight handles, and its size ----
      Rectangle {
        visible: win.mine
        x: win.sx - border.width
        y: win.sy - border.width
        width: win.sw + border.width * 2
        height: win.sh + border.width * 2
        color: "transparent"
        border.width: Retro.borderWidth
        border.color: Theme.orange
      }

      Repeater {
        // corners and the middle of each edge, as fractions of the selection
        model: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]

        Rectangle {
          required property var modelData

          visible: win.mine
          width: win.handleSize
          height: win.handleSize
          x: win.sx + win.sw * modelData[0] - width / 2
          y: win.sy + win.sh * modelData[1] - height / 2
          color: Theme.bg
          border.width: Retro.borderWidth
          border.color: Theme.orange
        }
      }

      // width x height in real pixels (the monitor's scale applied), and where the corner is
      Rectangle {
        visible: win.mine
        width: sizeText.implicitWidth + 16
        height: sizeText.implicitHeight + 8
        x: win.clamp(win.sx, 0, win.width - width)
        y: win.sy > height + 10 ? win.sy - height - 6 : win.sy + 6
        radius: Retro.corner
        color: Theme.bg
        border.width: Retro.borderWidth
        border.color: Theme.orange

        Text {
          id: sizeText
          anchors.centerIn: parent
          text: Math.round(win.sw * root.modelData.devicePixelRatio) + " x " + Math.round(win.sh * root.modelData.devicePixelRatio)
                + "    at " + RegionPicker.selX + "," + RegionPicker.selY
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      // what the keys do
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: hint.implicitWidth + 24
        height: hint.implicitHeight + 10
        radius: Retro.corner
        color: Theme.bg
        border.width: Retro.borderWidth
        border.color: Theme.fgDim

        Text {
          id: hint
          anchors.centerIn: parent
          text: "DRAG TO SELECT     RIGHT CLICK: CLEAR     ENTER: " + RegionPicker.verb + "     ESC: CANCEL"
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      // ---- the mouse ----
      MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: win.cursorFor(grip)

        property int grip: 0          // what a press here would take hold of
        property int kind: 0          // what is being dragged
        property var from: ({})       // the selection when the press happened
        property real pressX: 0
        property real pressY: 0

        onPositionChanged: mouse => {
          if (pressed)
            win.dragBy(kind, from, mouse.x, mouse.y, mouse.x - pressX, mouse.y - pressY);
          else
            grip = win.gripAt(mouse.x, mouse.y);
        }

        onPressed: mouse => {
          if (mouse.button === Qt.RightButton) {
            if (RegionPicker.hasSel)
              RegionPicker.retract();
            else
              RegionPicker.cancel();
            return;
          }
          pressX = mouse.x;
          pressY = mouse.y;
          kind = win.gripAt(mouse.x, mouse.y) || win.gNew;
          from = { x: win.sx, y: win.sy, w: win.sw, h: win.sh, ox: mouse.x, oy: mouse.y };
          if (kind === win.gNew)
            win.put(mouse.x, mouse.y, mouse.x, mouse.y);
        }

        onReleased: {
          if (kind === win.gNew && !RegionPicker.hasSel)
            RegionPicker.setSel("", 0, 0, 0, 0);       // a click without a drag leaves nothing selected
          grip = win.gripAt(mouseX, mouseY);
          kind = 0;
        }

        onDoubleClicked: {
          if (win.gripAt(mouseX, mouseY) === win.gIn)
            RegionPicker.confirm();
        }
      }

      // ---- the keyboard ----
      Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
          const step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
          switch (event.key) {
          case Qt.Key_Escape:
            RegionPicker.cancel();
            break;
          case Qt.Key_Return:
          case Qt.Key_Enter:
            RegionPicker.confirm();
            break;
          case Qt.Key_Left:
            win.nudge(-step, 0);
            break;
          case Qt.Key_Right:
            win.nudge(step, 0);
            break;
          case Qt.Key_Up:
            win.nudge(0, -step);
            break;
          case Qt.Key_Down:
            win.nudge(0, step);
            break;
          default:
            return;
          }
          event.accepted = true;
        }
      }
    }
  }
}
