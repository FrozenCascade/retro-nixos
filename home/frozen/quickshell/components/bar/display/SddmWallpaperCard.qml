import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import qs.components.bar.calendar

// LOG IN MENU - SDDM: the picture behind the login screen. Folded until asked for, like the shared card above.
// The login theme cannot read your home folder, so WallpaperState.setLoginImage copies the picture to
// /var/lib/sddm-retro (a folder modules/desktop/sddm.nix creates). Without a choice the theme shows the
// wallpaper bundled with it.
Rectangle {
  id: card

  readonly property var cfg: WallpaperState.cfg("")
  property bool open: false
  property bool picking: false

  height: col.implicitHeight + 24
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  Column {
    id: col
    x: 12
    y: 12
    width: card.width - 24
    spacing: 8

    Item {
      width: parent.width
      height: 22

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "LOG IN MENU - SDDM"
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: card.open ? "-" : "+"
        color: Theme.orange
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 2
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.open = !card.open
      }
    }

    Column {
      visible: card.open
      width: parent.width
      spacing: 8

      Row {
        spacing: 8

        Rectangle {
          width: 96
          height: 54
          radius: Retro.corner
          color: Theme.bgAlt
          border.width: 2
          border.color: Theme.fgDim
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: 2
            asynchronous: true
            sourceSize: Qt.size(192, 108)
            fillMode: Image.PreserveAspectCrop
            source: card.cfg.loginImage !== "" ? "file://" + card.cfg.loginImage : ""
          }
        }

        Column {
          spacing: 6

          MiniButton {
            text: card.picking ? "CLOSE" : "CHOOSE PICTURE"
            onClicked: {
              card.picking = !card.picking;
              if (card.picking)
                WallpaperState.scanPictures();
            }
          }

          MiniButton {
            text: "THEME PICTURE"
            active: card.cfg.loginImage === ""
            onClicked: WallpaperState.setLoginImage("")
          }
        }
      }

      PicturePicker {
        visible: card.picking
        width: parent.width
        onPicked: path => {
          WallpaperState.setLoginImage(path);
          card.picking = false;
        }
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "SHOWN AFTER THE NEXT LOGOUT. THE PICTURE IS COPIED, SO DELETING THE ORIGINAL IS FINE."
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }
  }
}
