import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import qs

// Takes over desktop notifications and shows them as a stack in the top right corner.
Scope {
  id: root

  property var screens: []                   // monitors that show the popups

  readonly property real cardWidth: 360
  readonly property real topOffset: 44       // clears the top bar
  readonly property real rightMargin: 12

  NotificationServer {
    id: server

    keepOnReload: true           // popups survive editing and reloading the config
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    actionsSupported: true

    onNotification: notification => {
      NotifStore.record(notification);
      if (!NotifStore.silent || notification.urgency === NotificationUrgency.Critical) {
        notification.tracked = true;
        Sounds.play(notification.urgency === NotificationUrgency.Critical ? "urgent" : "notify");
      }
    }
  }

  Variants {
    model: root.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData

      // only exists while there is something to show
      visible: server.trackedNotifications.values.length > 0 || NotifStore.temp.length > 0

      anchors {
        top: true
        right: true
      }
      margins {
        top: root.topOffset
        right: root.rightMargin
      }

      implicitWidth: root.cardWidth + Retro.shadowOffset
      implicitHeight: stack.implicitHeight + Retro.shadowOffset

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "notifications"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None   // a popup never takes the keyboard from a game or a typing window

      // only the cards take the mouse; the rest of the window is click-through
      mask: Region {
        item: stack
      }

      Column {
        id: stack
        anchors {
          top: parent.top
          right: parent.right
        }
        spacing: 6

        Repeater {
          model: server.trackedNotifications

          NotificationCard {
            required property var modelData
            notification: modelData
            frameWidth: root.cardWidth
          }
        }
        Repeater {
          model: NotifStore.temp
          NotificationCard {
            required property var modelData
            notification: modelData
            frameWidth: root.cardWidth
          }
        }
      }
    }
  }
}
