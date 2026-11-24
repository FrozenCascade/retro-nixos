import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import qs.components.bar.calendar

// One monitor's wallpaper settings: the mode now, the mode it starts in, its picture, the options of the
// mode that is on, and the decor. Everything is stored per monitor name by WallpaperState.
Rectangle {
  id: card

  required property var monitor         // a Quickshell screen

  readonly property string name: monitor.name
  readonly property var cfg: WallpaperState.cfg(name)
  readonly property string mode: WallpaperState.modeOf(name)
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

    Text {
      text: WallpaperState.roleOf(card.name).toUpperCase() + "   " + card.name + (card.name === Settings.laptopMonitor ? "   LAPTOP" : "")
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize
    }

    // ---- mode ----
    Flow {
      width: parent.width
      spacing: 6

      Repeater {
        model: WallpaperState.modes

        MiniButton {
          required property var modelData

          text: modelData.name
          active: card.mode === modelData.id
          onClicked: WallpaperState.setMode(card.name, modelData.id)
        }
      }
    }

    Row {
      spacing: 8

      MiniButton {
        text: "START IN THIS MODE"
        active: card.cfg.defaultMode === card.mode
        onClicked: WallpaperState.set(card.name, "defaultMode", card.mode)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "STARTS IN " + WallpaperState.modeName(card.cfg.defaultMode)
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }

    // ---- effects (the settings of the rain are in the card for both monitors) ----
    Row {
      spacing: 8

      MiniButton {
        text: "RAIN"
        active: card.cfg.rain
        onClicked: WallpaperState.set(card.name, "rain", !card.cfg.rain)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: card.mode === "matrix" ? "NOT SHOWN IN MATRIX" : "FALLING RAIN OVER THE PICTURE"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }

    // ---- picture ----
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
          source: WallpaperState.fileUrl(card.name)
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
          active: card.cfg.image === ""
          onClicked: WallpaperState.set(card.name, "image", "")
        }
      }
    }

    PicturePicker {
      visible: card.picking
      width: parent.width
      onPicked: path => {
        WallpaperState.set(card.name, "image", path);
        card.picking = false;
      }
    }

    // colours, rain and audio bars are shared by both monitors: see SharedWallpaperCard.qml
  }
}
