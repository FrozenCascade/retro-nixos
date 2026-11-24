import Quickshell.Hyprland
import QtQuick
import qs

// Which popup is open on each side of the screen, and the rules for opening and closing them.
//
// Popups sit in three places: left (status, weather, quick), right (calendar, ai, tool-*) and
// center (overview). One popup per place. A left and a right popup can be open together; the
// overview closes both, and either one closes it. The launcher has its own window and ignores all this.
//
// To add a popup: pick a name. It opens on the left unless sideOf() below says otherwise.
Item {
  id: root

  // the bar listens: it shows itself when a popup opens and starts hiding when one closes
  signal opened
  signal closed

  property string leftPopup: ""
  property string rightPopup: ""
  property string centerPopup: ""
  property bool leftPinned: false       // the open popup stays when it loses focus
  property bool rightPinned: false
  property bool centerPinned: false
  property int quickTab: 0              // the tab the quick window opens on (set by the Super+X / Super+C shortcuts)

  readonly property bool anyOpen: leftPopup !== "" || rightPopup !== "" || centerPopup !== ""
  readonly property bool anyPinned: (leftPopup !== "" && leftPinned) || (rightPopup !== "" && rightPinned) || (centerPopup !== "" && centerPinned)

  // Popups do not close one by one when they lose focus (that is what `held` switches off).
  // They close together, in dismissUnpinned(): when the keyboard leaves every Quickshell window for a
  // normal window or the desktop, every popup that is not pinned closes.
  readonly property bool held: true

  property string lastClosed: ""        // which popup closed last, and when (for the click guard in toggle)
  property real lastClosedAt: 0
  property real lastOpenAt: 0

  function sideOf(name) {
    if (name === "overview")
      return "center";
    if (name === "calendar" || name === "ai" || name.startsWith("tool-"))
      return "right";
    return "left";
  }

  function isOpen(name) {
    return leftPopup === name || rightPopup === name || centerPopup === name;
  }

  // closes the popup only if it is open
  function close(name) {
    if (name === "")
      return;
    const side = sideOf(name);
    if (root[side + "Popup"] !== name)
      return;
    lastClosed = name;
    lastClosedAt = Date.now();
    root[side + "Popup"] = "";
    root[side + "Pinned"] = false;
    if (name === "quick")
      quickTab = 0;
    if (name === "ai")
      AiState.hide();
    closed();
  }

  function closeAll() {
    for (const side of ["left", "right", "center"])
      close(root[side + "Popup"]);
  }

  function toggle(name) {
    const side = sideOf(name);
    if (root[side + "Popup"] === name) {
      close(name);
      return;
    }

    // the click that just dismissed this popup must not reopen it
    if (lastClosed === name && Date.now() - lastClosedAt < 250)
      return;

    if (side === "center") {
      close(leftPopup);
      close(rightPopup);
    } else {
      close(root[side + "Popup"]);
      close(centerPopup);
    }
    root[side + "Popup"] = name;
    root[side + "Pinned"] = false;
    lastOpenAt = Date.now();
    if (name === "ai")
      AiState.show();
    opened();
  }

  // ---- closing together when the keyboard leaves the shell ----
  readonly property var focusedWin: Hyprland.toplevels.values.find(t => t.activated) || null
  readonly property bool focusInShell: focusedWin !== null && Desktop.isShell(focusedWin)

  onFocusInShellChanged: {
    if (focusInShell)
      dismissTimer.stop();
    else
      dismissTimer.restart();
  }

  Timer {
    id: dismissTimer
    interval: 250
    onTriggered: root.dismissUnpinned()
  }

  function dismissUnpinned() {
    if (focusInShell)
      return;
    // a popup that has only just opened may not have the keyboard yet
    if (Date.now() - lastOpenAt < 700) {
      dismissTimer.restart();
      return;
    }
    if (centerPopup !== "" && !centerPinned)
      close(centerPopup);
    // the system popup has its own click-away grab, and the AI window pins and hides itself
    if (leftPopup !== "" && leftPopup !== "status" && !leftPinned)
      close(leftPopup);
    if (rightPopup !== "" && rightPopup !== "ai" && !rightPinned)
      close(rightPopup);
  }

  // The dock's hide button hides what hangs off it: unpinned windows close, pinned ones just hide.
  Connections {
    target: LauncherState

    function onDockHiddenChanged() {
      if (!LauncherState.dockHidden)
        return;
      if (root.centerPopup !== "" && !root.centerPinned)
        root.close(root.centerPopup);
      if ((root.leftPopup === "weather" || root.leftPopup === "quick") && !root.leftPinned)
        root.close(root.leftPopup);
      if (root.rightPopup === "calendar" && !root.rightPinned)
        root.close("calendar");
    }
  }

  // The AI window is its own program: it can show or hide itself, and the bar follows.
  Connections {
    target: AiState

    function onOpenChanged() {
      if (AiState.open && root.rightPopup !== "ai")
        root.toggle("ai");
      else if (!AiState.open && root.rightPopup === "ai")
        root.close("ai");
    }
  }
}
