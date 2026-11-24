import Quickshell.Hyprland
import QtQuick
import qs
import qs.components.bar.calendar
import qs.components.bar.overview
import qs.components.bar.quick
import qs.components.bar.system
import qs.components.bar.weather

// Every popup the bar can open, wired to the PopupController. Which one is open, and when it closes,
// is decided by the controller; this file only says what each popup needs.
// To add a popup: add it here, give it a name in PopupController, and put a button for it in BarLeft/BarRight.
Item {
  id: root

  required property var popups          // PopupController
  required property var anchorWindow    // the bar window, which popups hang from
  required property var leftGroup       // BarLeft: the system and weather popups open under its buttons
  property string workspace: ""         // the workspace this monitor is showing
  property var focusedWindow: null      // the window that was focused (the overview highlights it)

  property real barHeight: 36
  readonly property real edge: 10       // gap to the left edge of the screen (the system popup uses it)
  readonly property real underBar: barHeight + 4

  // ---- center: the overview, every workspace and its windows ----
  OverviewPopup {
    open: root.popups.isOpen("overview")
    pinned: root.popups.centerPinned
    held: root.popups.held
    currentWorkspace: root.workspace
    focusedWindow: root.focusedWindow
    onCloseRequested: root.popups.close("overview")
    onPinToggled: root.popups.centerPinned = !root.popups.centerPinned
  }

  // ---- left: system, weather, quick ----
  SystemPopup {
    id: system
    open: root.popups.isOpen("status")
    pinned: root.popups.leftPinned
    anchorWindow: root.anchorWindow
    anchorX: root.edge
    anchorY: root.underBar
    anchorWidth: root.leftGroup.statusButton.width
    onCloseRequested: root.popups.close("status")
    onPinToggled: root.popups.leftPinned = !root.popups.leftPinned
  }

  WeatherPopup {
    open: root.popups.isOpen("weather") && !Weather.hidden
    pinned: root.popups.leftPinned
    held: root.popups.held
    onCloseRequested: root.popups.close("weather")
    onPinToggled: root.popups.leftPinned = !root.popups.leftPinned
  }

  // shown instead of the weather window while the weather is hidden
  WeatherHiddenNote {
    id: weatherNote
    open: root.popups.isOpen("weather") && Weather.hidden
    anchorWindow: root.anchorWindow
    anchorX: root.leftGroup.x + root.leftGroup.weatherButton.x
    anchorY: root.underBar
    anchorWidth: root.leftGroup.weatherButton.width
    onCloseRequested: root.popups.close("weather")
  }

  QuickPopup {
    open: root.popups.isOpen("quick")
    startTab: root.popups.quickTab
    pinned: root.popups.leftPinned
    held: root.popups.held
    onCloseRequested: root.popups.close("quick")
    onPinToggled: root.popups.leftPinned = !root.popups.leftPinned
  }

  // ---- right: calendar (the tool windows and the AI window are opened from BarRight) ----
  CalendarPopup {
    open: root.popups.isOpen("calendar")
    pinned: root.popups.rightPinned
    held: root.popups.held
    onCloseRequested: root.popups.close("calendar")
    onPinToggled: root.popups.rightPinned = !root.popups.rightPinned
  }

  // ---- click-away handlers ----
  // The floating windows close themselves when they lose the keyboard. These two are layer-shell
  // popups, so they need a grab: a click anywhere else closes them.
  HyprlandFocusGrab {
    windows: [system.popupWindow]
    active: root.popups.isOpen("status") && !root.popups.leftPinned && root.popups.rightPopup === "" && !LauncherState.open
    onCleared: root.popups.close("status")
  }

  HyprlandFocusGrab {
    windows: [weatherNote.popupWindow]
    active: root.popups.isOpen("weather") && Weather.hidden
    onCleared: root.popups.close("weather")
  }
}
