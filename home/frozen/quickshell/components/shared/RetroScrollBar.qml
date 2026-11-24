import QtQuick
import qs

// A thin scroll bar for a Flickable or ListView. Put it beside the list (you anchor it) and set `target`.
// Drag the handle, or press anywhere in the groove to jump there. It hides itself when everything fits.
Item {
  id: bar

  property Flickable target: null

  // edit here
  property color handleColor: Theme.fgDim
  property color activeColor: Theme.orange      // while it is held

  readonly property real range: target ? Math.max(0, target.contentHeight - target.height) : 0

  width: 6
  visible: range > 0 && target && target.visible

  function seek(y) {
    const free = bar.height - handle.height;
    if (free > 0)
      target.contentY = Math.max(0, Math.min(range, (y - handle.height / 2) / free * range));
  }

  Rectangle {
    anchors.fill: parent
    radius: 2
    color: Retro.inset
  }

  Rectangle {
    id: handle
    width: parent.width
    height: target && target.contentHeight > 0 ? Math.max(24, bar.height * target.height / target.contentHeight) : 24
    y: bar.range > 0 ? target.contentY / bar.range * (bar.height - height) : 0
    radius: 2
    color: grab.pressed ? bar.activeColor : bar.handleColor
  }

  MouseArea {
    id: grab
    anchors { fill: parent; leftMargin: -4; rightMargin: -3 }       // easier to hit than 6 pixels
    onPressed: mouse => bar.seek(mouse.y)
    onPositionChanged: mouse => {
      if (pressed)
        bar.seek(mouse.y);
    }
  }
}
