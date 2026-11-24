import Quickshell.Services.Mpris
import QtQuick
import "../../lib/playerArt.js" as PlayerArt
import qs

// Right side of the lock window: what is playing, with previous / play / next.
Rectangle {
  id: card

  // the player that is playing, else the first one
  readonly property var player: {
    const all = Mpris.players.values;
    return all.find(p => p.isPlaying) || all[0] || null;
  }
  readonly property string title: player && player.trackTitle ? player.trackTitle : "NOTHING PLAYING"
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property string art: (PlayerArt.urlFor(player) || ArtLookup.art)

  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  Column {
    x: 14
    y: 14
    width: parent.width - 28
    spacing: 8

    Rectangle {
      width: parent.width
      height: width * 0.8
      radius: Retro.corner
      color: Theme.bgAlt
      border.width: Retro.borderWidth
      border.color: Theme.fgDim
      clip: true

      Image {
        anchors.fill: parent
        anchors.margins: Retro.borderWidth
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        source: card.art
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: card.art === ""
        text: Glyphs.music
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize + 12
      }
    }

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: card.title.toUpperCase()
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize
    }

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: card.artist.toUpperCase()
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 2
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8

      LockKey {
        glyph: Glyphs.skipPrevious
        enabled: card.player !== null && card.player.canGoPrevious
        onClicked: card.player.previous()
      }

      LockKey {
        glyph: card.player && card.player.isPlaying ? Glyphs.pause : Glyphs.play
        enabled: card.player !== null && card.player.canTogglePlaying
        onClicked: card.player.togglePlaying()
      }

      LockKey {
        glyph: Glyphs.skipNext
        enabled: card.player !== null && card.player.canGoNext
        onClicked: card.player.next()
      }
    }
  }
}
