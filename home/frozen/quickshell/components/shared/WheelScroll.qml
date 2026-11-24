import QtQuick

// Mouse wheel scrolling for a Flickable or ListView, with a set distance per wheel notch.
// Lay it over the list (anchors.fill: the list); clicks and hovering still reach what is underneath.
MouseArea {
  id: area

  required property Flickable view
  property real notchPixels: 90            // edit here: pixels per wheel notch, raise for faster
  property real touchpadScale: 1.4

  acceptedButtons: Qt.NoButton

  onWheel: wheel => {
    const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * touchpadScale
      : wheel.angleDelta.y / 120 * notchPixels;
    const max = Math.max(0, view.contentHeight - view.height);
    view.contentY = Math.max(0, Math.min(max, view.contentY - dy));
  }
}
