import QtQuick
import QtQuick.Effects
import qs

// The window title in the middle of the bar, with the window's icon to the left of the text; the icon
// and the text are centered together. The bar anchors it between the workspace buttons on its left and
// the date on its right, so it stretches to join them.
// Click: the workspace overview. Middle click: show the desktop.
// The icon is always one color, the bar's text color: the theme's symbolic icon when there is one,
// otherwise a glyph chosen in lib/appicons.js.
Rectangle {
  id: title

  property string text: ""
  property var window: null             // the window whose icon is shown
  property bool dim: false              // nothing to show: "[ IDLE ]" (no icon then)
  property bool open: false             // the overview is open
  property string workspace: ""         // the workspace being shown: scrolling over the title steps through them

  signal clicked
  signal middleClicked

  readonly property string iconSource: window ? Desktop.symbolicIcon(window) : ""
  readonly property string glyph: window ? Desktop.glyphFor(window) : ""
  readonly property string fullIcon: window ? Desktop.titleIcon(window) : ""     // shown in full color
  readonly property bool showIcon: !dim && (fullIcon !== "" || iconSource !== "" || glyph !== "")

  height: 24
  radius: Retro.corner
  color: title.open ? Theme.bgSel : Retro.inset
  border.width: Retro.borderWidth
  border.color: title.open ? Theme.orange : (mouse.hot ? Theme.fg : Theme.fgDim)

  Item {
    id: content
    anchors {
      fill: parent
      leftMargin: 10
      rightMargin: 10
    }

    Row {
      anchors.centerIn: parent
      spacing: 8

      // the icon itself is only the source of the picture next to it
      Item {
        id: iconBox
        anchors.verticalCenter: parent.verticalCenter
        visible: title.showIcon
        width: 18
        height: 18

        Image {
          id: appIcon
          anchors.fill: parent
          sourceSize.width: 36
          sourceSize.height: 36
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          source: title.fullIcon !== "" ? title.fullIcon : title.iconSource
          visible: title.fullIcon !== ""
        }

        MultiEffect {
          anchors.fill: appIcon
          visible: title.fullIcon === "" && title.iconSource !== ""
          source: appIcon
          colorization: 1.0
          colorizationColor: Theme.fg
        }

        // no symbolic icon in the theme: a glyph in the text color (lib/appicons.js)
        Text {
          anchors.centerIn: parent
          visible: title.fullIcon === "" && title.iconSource === ""
          text: title.glyph
          color: Theme.fg
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize + 1
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, content.width - (iconBox.visible ? iconBox.width + parent.spacing : 0))
        elide: Text.ElideRight
        text: title.text
        color: title.dim ? Theme.fgDim : Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }
  }

  WorkspaceWheel {
    id: stepper
    workspace: title.workspace
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    property bool hot: false
    onEntered: hot = true
    onExited: hot = false
    onPositionChanged: hot = true

    onWheel: wheel => stepper.handle(wheel)

    onClicked: mouse => {
      hot = false;
      if (mouse.button === Qt.MiddleButton)
        title.middleClicked();
      else
        title.clicked();
    }
  }
}
