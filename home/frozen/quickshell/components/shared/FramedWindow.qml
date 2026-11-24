import Quickshell
import QtQuick
import qs

// The floating window every panel shares: hard shadow, retro frame, title bar, and the rule
// "an unpinned panel closes when it loses the keyboard". Put the panel's contents inside it;
// they land in the frame, below the title bar, and `parent` is the frame.
Item {
  id: root

  property string windowTitle: ""       // what the Hyprland rule matches ("qs-quick")
  property string title: ""             // the text in the title bar
  property bool open: false
  property bool pinned: false           // the user's pin
  property bool held: false             // also stay open when focus moves to a window it may coexist with
  property bool showPin: true
  property real frameWidth: 440
  property real frameHeight: 640

  // who gets the keyboard when the window appears (default: the frame itself)
  property Item focusTarget: frame
  // true: a click on empty space gives the keyboard back to the frame (and leaves any text box)
  property bool clickFocusesFrame: true

  signal closeRequested
  signal pinToggled
  signal keyPressed(var event)          // keys the frame received; set event.accepted to claim one

  default property alias content: frame.data
    readonly property alias window: popup
    readonly property alias panel: frame

    FloatingWindow {
      id: popup
      title: root.windowTitle
      visible: root.open && !LauncherState.dockHidden
      color: "transparent"

      implicitWidth: root.frameWidth + Retro.shadowOffset
      implicitHeight: root.frameHeight + Retro.shadowOffset
      minimumSize: Qt.size(implicitWidth, implicitHeight)
      maximumSize: Qt.size(implicitWidth, implicitHeight)

      // true once the window has had the keyboard, so it is not closed before it ever got it
      property bool hadFocus: false

      Item {
        Window.onActiveChanged: {
          if (Window.active)
            popup.hadFocus = true;
          else if (popup.hadFocus && root.open && !root.pinned && !root.held && !LauncherState.dockHidden)
            root.closeRequested();
        }
      }

      onVisibleChanged: {
        if (visible) {
          hadFocus = false;
          root.focusTarget.forceActiveFocus();
        } else if (root.open && !LauncherState.dockHidden) {
          // closed from outside (for example with the close-window keybind)
          root.closeRequested();
        }
      }

      Rectangle {
        x: Retro.shadowOffset
        y: Retro.shadowOffset
        width: frame.width
        height: frame.height
        radius: Retro.corner
        color: Retro.shadowColor
      }

      Rectangle {
        id: frame
        width: root.frameWidth
        height: root.frameHeight
        radius: Retro.corner
        color: Theme.bg
        border.color: Theme.fg
        border.width: Retro.borderWidth
        focus: true

        Keys.onPressed: event => root.keyPressed(event)

        // swallows clicks on empty areas
        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (root.clickFocusesFrame)
              frame.forceActiveFocus();
          }
        }

        TitleBar {
          title: root.title
          showPin: root.showPin
          pinned: root.pinned
          onPinClicked: root.pinToggled()
          onCloseClicked: root.closeRequested()
        }
      }
    }
}
