import QtQuick

// When the top bar is visible. This item IS the hover zone: it is as tall as the bar while the bar
// shows, and only a thin strip at the top edge while it is hidden (the bar uses it as its input mask).
//
//   pinned      the bar always shows
//   unpinned    it slides in while the pointer is on the top edge, or a popup is open
//   hide        middle click on the pin: hidden until the pointer leaves and re-enters the top edge
Item {
  id: root

  property real barHeight: 36
  property real revealHeight: 4         // hover strip at the top edge while hidden
  property bool keepOpen: false         // a popup is open: the bar stays
  property bool keepPinned: false       // a pinned popup is open: the bar cannot be hidden by hand

  property bool pinned: true
  property bool shown: false            // unpinned: currently slid into view
  property bool manuallyHidden: false   // hidden by hand, until the pointer re-enters the top edge
  property bool revealArmed: false      // the pointer has left since the hide, so the next entry counts

  readonly property bool revealed: pinned || shown || keepOpen
  readonly property bool hovered: hover.hovered

  signal hiding                         // about to hide by hand (the bar closes its popups here)

  z: 10
  height: revealed ? barHeight : revealHeight

  function show() {
    if (manuallyHidden)
      return;
    hideTimer.stop();
    shown = true;
  }

  // start the countdown to hiding (it is cancelled if the pointer comes back)
  function scheduleHide() {
    hideTimer.restart();
  }

  function forceHide() {
    // a pinned popup keeps the bar up until it is unpinned
    if (pinned || keepPinned)
      return;
    manuallyHidden = true;
    hiding();

    // require a fresh entry into the top edge
    revealArmed = !hover.hovered;
    hideTimer.stop();
    shown = false;
  }

  function togglePinned() {
    pinned = !pinned;
    manuallyHidden = false;
    revealArmed = false;

    // unpinning while the pointer is on the bar: it hides once the pointer leaves
    shown = true;
    if (!pinned && !hover.hovered)
      hideTimer.restart();
  }

  HoverHandler {
    id: hover
    blocking: false

    onHoveredChanged: {
      if (!hovered) {
        if (root.manuallyHidden)
          root.revealArmed = true;
        else if (!root.pinned)
          hideTimer.restart();
        return;
      }

      if (root.manuallyHidden) {
        // a fresh entry into the top edge restores normal behavior
        if (root.revealArmed) {
          root.manuallyHidden = false;
          root.revealArmed = false;
          root.show();
        }
        return;
      }

      root.show();
    }
  }

  Timer {
    id: hideTimer
    interval: 300
    onTriggered: {
      if (!hover.hovered && !root.pinned && !root.keepOpen)
        root.shown = false;
    }
  }
}
