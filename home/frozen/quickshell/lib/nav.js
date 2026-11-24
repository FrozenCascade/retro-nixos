.pragma library

// Keyboard navigation shared by the buttons, tabs, tiles and sliders in the popup windows.
// Tab and Shift+Tab are handled by Qt. This adds the arrow keys, Enter/Space, and scrolling a list so
// the control that has the keyboard stays in view.

var LEFT = 0x01000012, UP = 0x01000013, RIGHT = 0x01000014, DOWN = 0x01000015;
var ENTER = 0x01000005, RETURN = 0x01000004, SPACE = 0x20;

// Enter, Return or Space: press the control
function isPress(e) {
  return e.key === ENTER || e.key === RETURN || e.key === SPACE;
}

// Arrow keys: Up/Left go to the previous control, Down/Right to the next. Pass horizontal = false for
// a control that uses Left/Right itself (a slider, a text box). Returns true when the key moved focus.
function move(item, e, horizontal) {
  var side = horizontal !== false;
  var back = e.key === UP || (side && e.key === LEFT);
  var fwd = e.key === DOWN || (side && e.key === RIGHT);
  if (!back && !fwd)
    return false;
  var next = item.nextItemInFocusChain(fwd);
  if (next)
    next.forceActiveFocus();
  return true;
}

// scroll the list (Flickable) that holds `item` just enough to show it
function reveal(item) {
  var p = item.parent;
  while (p) {
    if (p.contentItem !== undefined && p.contentY !== undefined && p.interactive !== undefined) {
      var r = item.mapToItem(p.contentItem, 0, 0);
      if (r.y < p.contentY)
        p.contentY = Math.max(0, r.y - 8);
      else if (r.y + item.height > p.contentY + p.height)
        p.contentY = r.y + item.height - p.height + 8;
      return;
    }
    p = p.parent;
  }
}

if (typeof module !== "undefined")
  module.exports = { isPress: isPress, move: move, reveal: reveal };
