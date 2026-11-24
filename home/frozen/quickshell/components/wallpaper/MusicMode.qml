import Quickshell.Services.Mpris
import QtQuick
import "../../lib/playerArt.js" as PlayerArt
import qs

// MUSIC: what is playing (album art, title, artist, previous/play/next) with cava bars.
// Two layouts, chosen per monitor in the Display window:
//   bars      bars along the bottom edge, the player card in the lower left
//   centered  the player in the middle of the screen with a row of bars under it
Item {
  id: root

  property string monitorName: ""

  readonly property var cfg: WallpaperState.cfg(monitorName)
  readonly property bool centered: cfg.musicLayout === "centered"
  readonly property color barColor: WallpaperState.accentColor(cfg.cavaColor)

  // the player that is playing, else the first one
  readonly property var player: {
    const all = Mpris.players.values;
    return all.find(p => p.isPlaying) || all[0] || null;
  }

  readonly property string title: player && player.trackTitle ? player.trackTitle : "NOTHING PLAYING"
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property string art: (PlayerArt.urlFor(player) || ArtLookup.art)

  // a dark veil over the picture so the text stays readable
  Rectangle {
    anchors.fill: parent
    color: Theme.bg
    opacity: 0.45
  }

  CavaBars {
    visible: !root.centered
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: parent.height * 0.25
    barColor: root.barColor
  }

  // ---- the player card ----
  Item {
    id: card
    width: root.centered ? 320 : 380
    height: root.centered ? 430 : 140
    x: root.centered ? (root.width - width) / 2 : 40
    y: root.centered ? (root.height - height) / 2 - 40 : root.height - height - root.height * 0.25 - 24

    Rectangle {
      x: Retro.shadowOffset
      y: Retro.shadowOffset
      width: parent.width
      height: parent.height
      radius: Retro.corner
      color: Retro.shadowColor
    }

    Rectangle {
      anchors.fill: parent
      radius: Retro.corner
      color: Theme.bg
      border.width: Retro.borderWidth
      border.color: Theme.fg
    }

    // album art
    Rectangle {
      id: artBox
      x: 14
      y: 14
      width: root.centered ? card.width - 28 : card.height - 28
      height: width
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: Theme.fgDim
      clip: true

      Image {
        anchors.fill: parent
        anchors.margins: Retro.borderWidth
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.art
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: root.art === ""
        text: Glyphs.music
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize + 14
      }
    }

    // title and artist
    Column {
      x: root.centered ? 14 : artBox.x + artBox.width + 14
      y: root.centered ? artBox.y + artBox.height + 12 : 18
      width: card.width - x - 14
      spacing: 4

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: root.title.toUpperCase()
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 1
      }

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: root.artist.toUpperCase()
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }

    // previous, play or pause, next
    Row {
      x: root.centered ? (card.width - width) / 2 : artBox.x + artBox.width + 14
      y: card.height - height - 16
      spacing: 8

      WallButton {
        glyph: Glyphs.skipPrevious
        enabled: root.player !== null && root.player.canGoPrevious
        onClicked: root.player.previous()
      }

      WallButton {
        glyph: root.player && root.player.isPlaying ? Glyphs.pause : Glyphs.play
        enabled: root.player !== null && root.player.canTogglePlaying
        onClicked: root.player.togglePlaying()
      }

      WallButton {
        glyph: Glyphs.skipNext
        enabled: root.player !== null && root.player.canGoNext
        onClicked: root.player.next()
      }
    }
  }

  // centered layout: a short row of bars under the card
  CavaBars {
    visible: root.centered
    x: (root.width - width) / 2
    y: card.y + card.height + 30
    width: Math.min(root.width * 0.5, 560)
    height: 70
    barColor: root.barColor
  }
}
