import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs
import qs.components.shared

// One notification, drawn as a small retro window.
Item {
  id: card

  required property var notification        // a Quickshell Notification object
  property real frameWidth: 360

  readonly property int timeoutMs: 10000     // non-critical notifications disappear after this

  readonly property bool critical: notification.urgency === NotificationUrgency.Critical
  readonly property bool hovered: hover.hovered

  // true while some of the text is highlighted: the countdown waits
  readonly property bool holding: summaryText.selectedText !== "" || bodyText.selectedText !== ""

  // 1 = just arrived, 0 = about to disappear
  property real remaining: 1

  // every action except the default one (the default action is a click on the card)
  readonly property var extraActions: Array.from(notification.actions || []).filter(a => a.identifier !== "default")

  // the picture: the notification's own image, then its icon, then the app's icon
  readonly property string imageSource: {
    const n = notification;

    if (n.image && n.image !== "")
      return n.image;

    const ic = n.appIcon || "";

    if (ic.startsWith("/"))
      return "file://" + ic;

    if (ic !== "") {
      const p = Quickshell.iconPath(ic, true);
      if (p)
        return p;
    }

    const e = n.appName ? DesktopEntries.heuristicLookup(n.appName) : null;

    if (e && e.icon)
      return Quickshell.iconPath(e.icon, true) || "";

    return "";
  }

  function activate() {
    const def = Array.from(notification.actions || []).find(a => a.identifier === "default");

    if (def)
      def.invoke();

    notification.dismiss();
  }

  width: frameWidth + Retro.shadowOffset
  height: frame.height + Retro.shadowOffset

  // fade in
  opacity: 0
  NumberAnimation on opacity {
    from: 0
    to: 1
    duration: 150
  }

  // the countdown: paused while the mouse is over the card or text is selected,
  // and it never runs for critical ones
  NumberAnimation {
    id: countdown
    target: card
    property: "remaining"
    from: 1
    to: 0
    duration: card.timeoutMs
    running: !card.critical
    paused: card.hovered || card.holding

    onFinished: card.notification.expire()
  }

  HoverHandler {
    id: hover
  }

  // hard drop shadow
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
    width: card.frameWidth
    height: content.y + content.implicitHeight + 26

    radius: Retro.corner
    color: Theme.bg
    border.color: Theme.fg
    border.width: Retro.borderWidth

    // click on the card (not on the text): run the default action and close.
    // Middle or right click anywhere: just close.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

      onClicked: mouse => {
        if (mouse.button === Qt.LeftButton)
          card.activate();
        else
          card.notification.dismiss();
      }
    }

    TitleBar {
      title: card.notification.appName || "notification"
      color: card.critical ? Theme.red : Theme.fg
      onCloseClicked: card.notification.dismiss()
    }

    Column {
      id: content
      x: 12
      y: 36
      width: parent.width - 24
      spacing: 10

      // picture and text
      Item {
        width: parent.width
        height: Math.max(picture.visible ? 40 : 0, textColumn.implicitHeight)

        Image {
          id: picture
          x: 0
          y: 0
          width: 40
          height: 40
          sourceSize.width: 80
          sourceSize.height: 80
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          source: card.imageSource
          visible: source !== ""
        }

        Column {
          id: textColumn
          x: picture.visible ? 52 : 0
          width: parent.width - x
          spacing: 3

          // title (selectable, two lines at most)
          Item {
            width: parent.width
            height: Math.min(summaryText.implicitHeight, summaryMetrics.lineSpacing * 2)
            clip: true

            FontMetrics {
              id: summaryMetrics
              font: summaryText.font
            }

            TextEdit {
              id: summaryText
              width: parent.width
              text: card.notification.summary
              readOnly: true
              selectByMouse: true
              wrapMode: TextEdit.Wrap
              textFormat: TextEdit.PlainText
              color: Theme.fg
              selectionColor: Theme.aqua
              selectedTextColor: Theme.bg
              font.family: Theme.fontSans
              font.bold: true
              font.pointSize: Theme.fontSize

              HoverHandler {
                cursorShape: Qt.IBeamCursor
              }
            }
          }

          // message (selectable, four lines at most; simple markup and links work)
          Item {
            width: parent.width
            visible: card.notification.body !== ""
            height: Math.min(bodyText.implicitHeight, bodyMetrics.lineSpacing * 4)
            clip: true

            FontMetrics {
              id: bodyMetrics
              font: bodyText.font
            }

            TextEdit {
              id: bodyText
              width: parent.width
              text: card.notification.body
              readOnly: true
              selectByMouse: true
              wrapMode: TextEdit.Wrap
              textFormat: TextEdit.RichText
              color: Theme.fgDim
              selectionColor: Theme.aqua
              selectedTextColor: Theme.bg
              font.family: Theme.fontSans
              font.pointSize: Theme.fontSize - 1

              onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])

              HoverHandler {
                cursorShape: Qt.IBeamCursor
              }
            }
          }
        }
      }

      // extra action buttons
      Row {
        visible: card.extraActions.length > 0
        spacing: 6

        Repeater {
          model: card.extraActions

          Item {
            id: action
            required property var modelData

            width: actionLabel.implicitWidth + 20
            height: 24

            // button shadow, hidden while pressed
            Rectangle {
              x: 2
              y: 2
              width: parent.width
              height: parent.height
              radius: Retro.corner
              color: Retro.shadowColor
              visible: !actionMouse.pressed
            }

            Rectangle {
              x: actionMouse.pressed ? 2 : 0
              y: actionMouse.pressed ? 2 : 0
              width: parent.width
              height: parent.height
              radius: Retro.corner
              color: Theme.bgAlt
              border.width: Retro.borderWidth
              border.color: actionMouse.containsMouse ? Theme.fg : Theme.fgDim

              Text {
                id: actionLabel
                anchors.centerIn: parent
                text: action.modelData.text.toUpperCase()
                color: Theme.fg
                font.family: Theme.fontMono
                font.bold: true
                font.pointSize: Theme.fontSize - 2
              }
            }

            MouseArea {
              id: actionMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: {
                action.modelData.invoke();
                card.notification.dismiss();
              }
            }
          }
        }
      }
    }

    // time bar: shrinks over the 10 seconds, solid red for critical ones
    Rectangle {
      x: 12
      y: parent.height - 14
      width: parent.width - 24
      height: 4
      color: card.critical ? Theme.red : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18)

      Rectangle {
        visible: !card.critical
        width: parent.width * card.remaining
        height: parent.height
        color: Theme.orange
      }
    }
  }
}
