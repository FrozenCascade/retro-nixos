import QtQuick
import qs
import "../../../lib/nav.js" as Nav

// A thin slider with a round handle, like KDE's volume sliders. `value` is a volume (1.0 = 100%);
// `maxValue` is where the slider ends (1.5 while MAX is on, with a mark at 100%).
// Click, drag, or scroll the wheel over it (5% a notch).
Item {
  id: slider

  property real value: 0
  property real maxValue: 1.0
  property bool dim: false
  property color fill: Theme.blue
  property real step: 0.05

  signal moved(real v)
  signal muteKey                        // the M key, for the row that owns this slider

  // keyboard: Left/Right change it (Shift = 1%), Home/End jump, M mutes, Up/Down move to another control
  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      const d = (event.key === Qt.Key_Left ? -1 : 1) * ((event.modifiers & Qt.ShiftModifier) ? 0.01 : slider.step);
      slider.moved(Math.round(Math.max(0, Math.min(slider.maxValue, slider.value + d)) * 100) / 100);
      event.accepted = true;
    } else if (event.key === Qt.Key_Home) {
      slider.moved(0);
      event.accepted = true;
    } else if (event.key === Qt.Key_End) {
      slider.moved(slider.maxValue);
      event.accepted = true;
    } else if (event.key === Qt.Key_M) {
      slider.muteKey();
      event.accepted = true;
    } else if (Nav.move(slider, event, false)) {
      event.accepted = true;
    }
  }
  onActiveFocusChanged: {
    if (activeFocus)
      Nav.reveal(slider);
  }

  readonly property real handle: 16
  readonly property real frac: maxValue > 0 ? Math.max(0, Math.min(1, value / maxValue)) : 0

  implicitHeight: 20
  height: implicitHeight

  function setFrom(x) {
    moved(Math.round(Math.max(0, Math.min(1, (x - handle / 2) / (width - handle))) * maxValue * 100) / 100);
  }

  Rectangle {
    id: track
    y: (parent.height - 4) / 2
    width: parent.width
    height: 4
    radius: 2
    color: Retro.inset
    border.width: 1
    border.color: Theme.fgDim
  }

  Rectangle {
    y: track.y
    width: knob.x + slider.handle / 2
    height: 4
    radius: 2
    color: slider.dim ? Theme.fgDim : (slider.value > 1.001 ? Theme.orange : slider.fill)
  }

  // the 100% mark, shown when the slider goes beyond it
  Rectangle {
    visible: slider.maxValue > 1.001
    x: (1 / slider.maxValue) * (slider.width - slider.handle) + slider.handle / 2 - 1
    y: track.y - 4
    width: 2
    height: 12
    color: Theme.fg
    opacity: 0.55
  }

  Rectangle {
    id: knob
    x: slider.frac * (slider.width - slider.handle)
    y: (parent.height - slider.handle) / 2
    width: slider.handle
    height: slider.handle
    radius: slider.handle / 2
    color: Theme.bg
    border.width: 2
    border.color: slider.activeFocus ? Theme.yellow : (slider.dim ? Theme.fgDim : Theme.fg)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    property real acc: 0

    onPressed: mouse => slider.setFrom(mouse.x)
    onPositionChanged: mouse => {
      if (pressed)
        slider.setFrom(mouse.x);
    }
    onWheel: wheel => {
      wheel.accepted = true;
      acc += wheel.angleDelta.y;
      while (Math.abs(acc) >= 120) {
        const dir = acc > 0 ? 1 : -1;
        acc -= dir * 120;
        slider.moved(Math.round(Math.max(0, Math.min(slider.maxValue, slider.value + dir * slider.step)) * 100) / 100);
      }
    }
  }
}
