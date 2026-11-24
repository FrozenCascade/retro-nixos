import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import qs.components.bar.calendar

// The wallpaper options that both monitors share: colours, music layout, rain and the audio bars.
// They are kept once in WallpaperState (see its perMonitor list), so this card needs no monitor.
// The picture, the mode and the starting mode stay on each monitor's card (MonitorWallpaperCard).
// Sits under the monitor cards and folds away: click the header.
Rectangle {
  id: card

  readonly property var cfg: WallpaperState.cfg("")
  property bool open: false                 // folded until asked for
  property bool picking: false              // the lock picture chooser

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
        text: "BOTH MONITORS: COLOURS AND OPTIONS"
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
      id: body
      visible: card.open
      width: parent.width
      spacing: 8

    SectionHead { width: parent.width; text: "DESKTOP: SELECTION COLOUR" }
    AccentRow {
      width: parent.width
      monitorName: ""
      option: "selectColor"
    }

    SectionHead { width: parent.width; text: "MUSIC: LAYOUT" }
    Row {
      spacing: 6

      MiniButton {
        text: "BARS AT THE BOTTOM"
        active: card.cfg.musicLayout === "bars"
        onClicked: WallpaperState.set("", "musicLayout", "bars")
      }

      MiniButton {
        text: "CENTERED"
        active: card.cfg.musicLayout === "centered"
        onClicked: WallpaperState.set("", "musicLayout", "centered")
      }
    }

    SectionHead { width: parent.width; text: "MATRIX: RAIN COLOUR" }
    AccentRow {
      width: parent.width
      monitorName: ""
      option: "matrixColor"
    }

    // one row per slider; add a { label, key } pair here to expose another 0..1 setting
    Repeater {
      model: [
        { label: "SPEED", key: "matrixSpeed" },
        { label: "DENSITY", key: "matrixDensity" }
      ]

      Item {
        required property var modelData

        width: col.width
        height: 24

        Text {
          width: 70
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        LineSlider {
          x: 76
          width: parent.width - 76
          anchors.verticalCenter: parent.verticalCenter
          value: card.cfg[parent.modelData.key]
          step: 0.05
          fill: Theme.green
          onMoved: v => WallpaperState.set("", parent.modelData.key, Math.round(v * 100) / 100)
        }
      }
    }

    // ---- rain over the picture (switched on per monitor, on its own card) ----
    SectionHead { width: parent.width; text: "RAIN OVER THE PICTURE: COLOUR" }
    AccentRow {
      width: parent.width
      monitorName: ""
      option: "rainColor"
    }

    Repeater {
      model: [
        { label: "SPEED", key: "rainSpeed" },
        { label: "DENSITY", key: "rainDensity" },
        { label: "SLANT", key: "rainSlant" }
      ]

      Item {
        required property var modelData

        width: col.width
        height: 24

        Text {
          width: 70
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        LineSlider {
          x: 76
          width: parent.width - 76
          anchors.verticalCenter: parent.verticalCenter
          value: card.cfg[parent.modelData.key]
          step: 0.05
          fill: Theme.aqua
          onMoved: v => WallpaperState.set("", parent.modelData.key, Math.round(v * 100) / 100)
        }
      }
    }

    Row {
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 70
        text: "FRAMES"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Repeater {
        model: WallpaperState.rainFpsChoices

        MiniButton {
          required property int modelData

          text: String(modelData)
          active: card.cfg.rainFps === modelData
          onClicked: WallpaperState.set("", "rainFps", modelData)
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "LOWER IS LIGHTER"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }

    SectionHead { width: parent.width; text: "MUSIC: BAR COLOUR" }
    AccentRow {
      width: parent.width
      monitorName: ""
      option: "cavaColor"
    }

    // ---- lock screen (Super+L) ----
    SectionHead { width: parent.width; text: "LOCK SCREEN PICTURE" }
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
          source: card.cfg.lockImage !== "" ? "file://" + card.cfg.lockImage : WallpaperState.fileUrl(Settings.externalMonitor)
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
          text: "SAME AS DESKTOP"
          active: card.cfg.lockImage === ""
          onClicked: WallpaperState.set("", "lockImage", "")
        }
      }
    }

    PicturePicker {
      visible: card.picking
      width: parent.width
      onPicked: path => {
        WallpaperState.set("", "lockImage", path);
        card.picking = false;
      }
    }

    CheckRow {
      label: "BLUR THE PICTURE"
      checked: card.cfg.lockBlur
      onToggled: value => WallpaperState.set("", "lockBlur", value)
    }
    }
  }
}
