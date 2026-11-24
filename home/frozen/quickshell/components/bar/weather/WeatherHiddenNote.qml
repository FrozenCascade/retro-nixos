import Quickshell
import QtQuick
import qs
import qs.components.shared

// A small note under the weather button, shown instead of the weather window while the weather is
// hidden (middle click on the button hides it and shows it again).
Item {
  id: root

  property bool open: false
  property var anchorWindow: null
  property real anchorX: 0
  property real anchorY: 0
  property real anchorWidth: 0

  // the window itself, so the bar's click-outside handler can include it
  readonly property var popupWindow: popup

  signal closeRequested

  PopupWindow {
    id: popup
    visible: root.open
    color: "transparent"

    anchor.window: root.anchorWindow
    anchor.rect.x: root.anchorX
    anchor.rect.y: root.anchorY
    anchor.rect.width: root.anchorWidth
    anchor.rect.height: 1
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: frame.width + Retro.shadowOffset
    implicitHeight: frame.height + Retro.shadowOffset

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
      width: 270
      height: 102
      radius: Retro.corner
      color: Theme.bg
      border.color: Theme.fg
      border.width: Retro.borderWidth

      TitleBar {
        title: "Weather"
        onCloseClicked: root.closeRequested()
      }

      Column {
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          leftMargin: 14
          rightMargin: 14
          topMargin: 36
        }
        spacing: 4

        Text {
          text: "WEATHER IS HIDDEN"
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Middle-click the weather button to see it again."
          color: Theme.fgDim
          font.family: Theme.fontSans
          font.pointSize: Theme.fontSize - 1
        }
      }
    }
  }
}
