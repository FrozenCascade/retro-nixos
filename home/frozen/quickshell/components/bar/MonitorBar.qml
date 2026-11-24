import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.components.bar.center

// The top bar of one monitor: the window, and the layout of what is on it.
//   AutoHide          when the bar shows (pin, autohide, hide by hand)
//   PopupController   which popup is open, and when they close
//   BarLeft/BarRight  the buttons at each end
//   center/           workspace buttons, the window title in the middle, the workspace blip
//   PopupHost         the popups themselves
PanelWindow {
  id: bar

  required property var modelData
  screen: modelData

  readonly property real barHeight: 36
  readonly property real revealHeight: 4        // hover strip at the top edge while hidden

  // the workspace this monitor is showing
  readonly property var monitor: Hyprland.monitorFor(modelData)
  readonly property string wsName: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : ""

  anchors {
    top: true
    left: true
    right: true
  }
  implicitHeight: barHeight
  color: "transparent"

  // pinned: reserves its space at the top. Autohide: floats over windows.
  exclusionMode: hider.pinned ? ExclusionMode.Auto : ExclusionMode.Ignore

  // only the visible bar (or the thin reveal strip) receives the mouse
  mask: Region {
    item: hider
  }

  Item {
    id: content
    anchors.fill: parent

    // ---- behavior ----
    AutoHide {
      id: hider
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
      }
      barHeight: bar.barHeight
      revealHeight: bar.revealHeight
      keepOpen: popupState.anyOpen
      keepPinned: popupState.anyPinned
      onHiding: popupState.closeAll()
    }

    PopupController {
      id: popupState
      onOpened: hider.show()
      onClosed: hider.scheduleHide()
    }

    // keyboard shortcuts into the bar (qs ipc call bar ...)
    BarIpc {
      popups: popupState
      hider: hider
    }

    // ---- the bar itself (slides up out of view when hidden) ----
    Rectangle {
      id: body
      width: parent.width
      height: bar.barHeight
      color: Theme.bg

      y: hider.revealed ? 0 : -height

      Behavior on y {
        NumberAnimation {
          duration: 160
          easing.type: Easing.OutCubic
        }
      }

      // bottom line
      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
        }
        height: 2
        color: Theme.fg
      }

      // everything sits one pixel above the middle, so it clears the bottom line
      BarLeft {
        id: leftButtons
        popups: popupState
        autoHide: hider
        anchors {
          left: parent.left
          leftMargin: 10
          verticalCenter: parent.verticalCenter
          verticalCenterOffset: -1
        }
      }

      WorkspaceButtons {
        id: workspaces
        current: bar.wsName
        focusedWindow: tracker.window
        anchors {
          left: leftButtons.right
          leftMargin: 4
          verticalCenter: parent.verticalCenter
          verticalCenterOffset: -1
        }
      }

      BarRight {
        id: rightGroup
        popups: popupState
        // The title is centered on the screen when the space left of it equals the space right of it.
        // Studio's song key stretches to make the right group exactly that wide
        // (22 = the margins around the title and the bar's edge: 10 + 6 + 6).
        fillWidth: workspaces.x + workspaces.width + 6 - 22 - titleBarrier.width
        anchors {
          right: parent.right
          rightMargin: 10
          verticalCenter: parent.verticalCenter
          verticalCenterOffset: -1
        }
      }

      // thin barrier between the window title and the right group
      BarSep {
        id: titleBarrier
        anchors {
          right: rightGroup.left
          rightMargin: 6
          verticalCenter: parent.verticalCenter
          verticalCenterOffset: -1
        }
      }

      // the focused window's title, stretched between the workspace buttons and the right group
      // Click: the overview. Middle click: show the desktop (and again to bring the windows back).
      TitleSection {
        anchors {
          left: workspaces.right
          right: titleBarrier.left
          leftMargin: 6
          rightMargin: 6
          verticalCenter: parent.verticalCenter
          verticalCenterOffset: -1
        }
        open: popupState.isOpen("overview")
        window: tracker.window
        workspace: bar.wsName
        dim: Desktop.showingDesktop(bar.wsName) || !tracker.window
        text: Desktop.showingDesktop(bar.wsName) ? "[ DESKTOP ]   middle-click to bring the windows back" : (tracker.window ? tracker.window.title : "[ IDLE ]")
        onClicked: popupState.toggle("overview")
        onMiddleClicked: Desktop.showDesktop(bar.wsName)
      }
    }

    // Which window the bar shows, ignoring Quickshell's own windows.
    FocusTracker {
      id: tracker
      workspace: bar.wsName
    }

    // A split-second label in the middle of the screen when the workspace changes.
    WorkspaceBlip {
      screen: bar.modelData
      workspace: bar.wsName
    }

    PopupHost {
      popups: popupState
      anchorWindow: bar
      leftGroup: leftButtons
      workspace: bar.wsName
      focusedWindow: tracker.window
      barHeight: bar.barHeight
    }
  }
}
