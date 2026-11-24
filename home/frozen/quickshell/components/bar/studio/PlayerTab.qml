import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar
import qs.components.bar.tools

// Whatever is playing (Mpris): the cover with a disc turning behind it, title, seek bar and the transport
// buttons. The same player is controlled from the bar (see StudioState for what each click and wheel does).
// The DISPLAY settings at the bottom are remembered; to change a default look, edit the values below.
Item {
  id: tab

  // ---- settings (edit here) ----
  readonly property real coverSize: 200          // the album cover, a square
  readonly property real discSize: 190
  readonly property real discPoke: 110           // how far the disc sticks out to the right of the cover
  readonly property var discKinds: [{ id: "dvd", name: "DVD" }, { id: "vinyl", name: "VINYL" }, { id: "none", name: "NONE" }]
  readonly property var coverBoxes: [{ id: "clear", name: "TRANSPARENT" }, { id: "glass", name: "SEE-THROUGH" }, { id: "solid", name: "OPAQUE" }]
  readonly property var spinSpeeds: [{ seconds: 9, name: "SLOW" }, { seconds: 5, name: "NORMAL" }, { seconds: 2.5, name: "FAST" }]

  // ---- remembered ----
  property string discKind: "dvd"
  property real spinSeconds: 5
  property bool showRemaining: false             // the right-hand time counts down instead of showing the length
  property string coverBox: "glass"              // the box behind the cover art: clear, glass (see-through) or solid

  readonly property var p: StudioState.player

  function clock(sec) {
    const s = Math.max(0, Math.floor(sec));
    const m = Math.floor(s / 60);
    return m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
  }

  // the chip for a player: its menu name, and when two of the same app play (two browser windows, say),
  // a number and the start of the title tell them apart
  function chipName(player) {
    const base = String((Desktop.overrideAny([player.desktopEntry, player.identity]) || {}).name || player.identity).toUpperCase();
    const same = StudioState.players.filter(q => q.identity === player.identity);
    if (same.length < 2)
      return base;
    const t = String(player.trackTitle || "").toUpperCase();
    return base + " " + (same.indexOf(player) + 1) + (t !== "" ? ": " + (t.length > 16 ? t.slice(0, 15) + "..." : t) : "");
  }

  StatePrefs {
    id: prefs
    file: "player-tab.json"
    data: ({ discKind: tab.discKind, spinSeconds: tab.spinSeconds, showRemaining: tab.showRemaining, coverBox: tab.coverBox })
    onLoaded: saved => {
      if (tab.discKinds.some(k => k.id === saved.discKind))
        tab.discKind = saved.discKind;
      if (tab.spinSpeeds.some(s => s.seconds === saved.spinSeconds))
        tab.spinSeconds = saved.spinSeconds;
      tab.showRemaining = saved.showRemaining === true;
      if (tab.coverBoxes.some(b => b.id === saved.coverBox))
        tab.coverBox = saved.coverBox;
    }
  }

  // the position is not pushed by players, so ask for it while the tab is showing
  Timer {
    interval: 500
    repeat: true
    running: tab.visible && StudioState.playing
    onTriggered: {
      if (tab.p)
        tab.p.positionChanged();
    }
  }

  Text {
    x: 20
    y: tab.height / 2 - height / 2
    width: tab.width - 40
    visible: tab.p === null
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: "NOTHING IS PLAYING\nSTART ANY PLAYER AND IT SHOWS UP HERE"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Flickable {
    id: flick
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight + 10
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: flick.width
      spacing: 12
      visible: tab.p !== null

      // ---- which player ----
      Flow {
        width: parent.width
        spacing: 6

        Repeater {
          model: StudioState.players

          MiniButton {
            required property var modelData

            text: tab.chipName(modelData)
            active: tab.p !== null && modelData.dbusName === tab.p.dbusName
            onClicked: StudioState.wanted = modelData.dbusName
          }
        }
      }

      // ---- the cover, with the disc behind it ----
      Item {
        width: parent.width
        height: tab.coverSize

        Item {
          id: pair
          anchors.horizontalCenter: parent.horizontalCenter
          width: tab.coverSize + (tab.discKind !== "none" ? tab.discPoke : 0)
          height: tab.coverSize

          SpinningDisc {
            visible: tab.discKind !== "none"
            width: tab.discSize
            height: tab.discSize
            x: tab.coverSize + tab.discPoke - tab.discSize
            anchors.verticalCenter: parent.verticalCenter
            kind: tab.discKind
            seconds: tab.spinSeconds
            spinning: StudioState.playing
            alive: tab.visible && tab.discKind !== "none"
          }

          Rectangle {
            width: tab.coverSize
            height: tab.coverSize
            radius: Retro.corner
            color: tab.coverBox === "solid" ? Theme.bgAlt : (tab.coverBox === "glass" ? Retro.inset : "transparent")
            border.width: tab.coverBox === "clear" ? 0 : Retro.borderWidth
            border.color: Theme.fgDim
            clip: true

            Image {
              anchors.fill: parent
              anchors.margins: tab.coverBox === "clear" ? 0 : 2
              asynchronous: true
              fillMode: Image.PreserveAspectCrop
              source: StudioState.art
              visible: source !== ""
            }

            Text {
              anchors.centerIn: parent
              visible: StudioState.art === ""
              text: Glyphs.music
              color: Theme.fgDim
              font.family: Theme.fontMono
              font.pointSize: Theme.fontSize + 20
            }
          }
        }
      }

      // ---- what is playing ----
      Column {
        width: parent.width
        spacing: 4

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          text: StudioState.title !== "" ? StudioState.title : "UNKNOWN TRACK"
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 1
        }

        Text {
          width: parent.width
          visible: StudioState.artist !== ""
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: StudioState.artist
          color: Theme.yellow
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Text {
          width: parent.width
          visible: StudioState.album !== ""
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: StudioState.album
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }
      }

      // ---- seek ----
      LineSlider {
        width: parent.width
        enabled: tab.p !== null && tab.p.canSeek && tab.p.lengthSupported
        value: tab.p ? tab.p.position : 0
        maxValue: tab.p && tab.p.length > 0 ? tab.p.length : 1
        step: StudioState.seekSeconds
        fill: Theme.orange
        onMoved: v => {
          if (tab.p && tab.p.canSeek)
            tab.p.position = v;
        }
      }

      Item {
        width: parent.width
        height: 16

        Text {
          anchors.left: parent.left
          text: tab.p ? tab.clock(tab.p.position) : ""
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        Text {
          anchors.right: parent.right
          text: {
            if (!tab.p || !tab.p.lengthSupported || tab.p.length <= 0)
              return "";
            return tab.showRemaining ? "-" + tab.clock(tab.p.length - tab.p.position) : tab.clock(tab.p.length);
          }
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }
      }

      // ---- buttons ----
      Item {
        width: parent.width
        height: 30

        Row {
          anchors.centerIn: parent
          spacing: 8

          MiniButton { height: 30; text: Glyphs.skipPrevious; enabled: tab.p !== null && tab.p.canGoPrevious; onClicked: StudioState.previous() }
          MiniButton { height: 30; text: "-" + StudioState.seekSeconds; enabled: tab.p !== null && tab.p.canSeek; onClicked: StudioState.seekStep(-1) }
          MiniButton { height: 30; text: StudioState.playing ? Glyphs.pause : Glyphs.play; padX: 26; active: StudioState.playing; onClicked: StudioState.togglePlay() }
          MiniButton { height: 30; text: "+" + StudioState.seekSeconds; enabled: tab.p !== null && tab.p.canSeek; onClicked: StudioState.seekStep(1) }
          MiniButton { height: 30; text: Glyphs.skipNext; enabled: tab.p !== null && tab.p.canGoNext; onClicked: StudioState.next() }
        }
      }

      // ---- the player's own volume ----
      SectionHead { width: parent.width; text: "VOLUME" }

      Row {
        width: parent.width
        spacing: 10

        LineSlider {
          width: parent.width - muteButton.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          enabled: tab.p !== null && tab.p.volumeSupported
          value: tab.p && tab.p.volumeSupported ? tab.p.volume : 0
          dim: StudioState.muted
          fill: Theme.blue
          onMoved: v => {
            if (tab.p && tab.p.volumeSupported)
              tab.p.volume = v;
          }
          onMuteKey: StudioState.toggleMute()
        }

        MiniButton {
          id: muteButton
          anchors.verticalCenter: parent.verticalCenter
          text: "MUTE"
          active: StudioState.muted
          onClicked: StudioState.toggleMute()
        }
      }

      // ---- how the tab looks ----
      SectionHead { width: parent.width; text: "DISPLAY" }

      Flow {
        width: parent.width
        spacing: 6

        Text {
          height: 22
          verticalAlignment: Text.AlignVCenter
          text: "DISC"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Repeater {
          model: tab.discKinds

          MiniButton {
            required property var modelData

            text: modelData.name
            active: tab.discKind === modelData.id
            onClicked: {
              tab.discKind = modelData.id;
              prefs.save();
            }
          }
        }

        Item { width: 10; height: 22 }

        Text {
          height: 22
          verticalAlignment: Text.AlignVCenter
          text: "SPIN"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Repeater {
          model: tab.spinSpeeds

          MiniButton {
            required property var modelData

            text: modelData.name
            active: tab.spinSeconds === modelData.seconds
            onClicked: {
              tab.spinSeconds = modelData.seconds;
              prefs.save();
            }
          }
        }

        Item { width: 10; height: 22 }

        Text {
          height: 22
          verticalAlignment: Text.AlignVCenter
          text: "TIME"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        MiniButton { text: "LENGTH"; active: !tab.showRemaining; onClicked: { tab.showRemaining = false; prefs.save(); } }
        MiniButton { text: "LEFT"; active: tab.showRemaining; onClicked: { tab.showRemaining = true; prefs.save(); } }

        Item { width: 10; height: 22 }

        Text {
          height: 22
          verticalAlignment: Text.AlignVCenter
          text: "COVER BOX"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Repeater {
          model: tab.coverBoxes

          MiniButton {
            required property var modelData

            text: modelData.name
            active: tab.coverBox === modelData.id
            onClicked: {
              tab.coverBox = modelData.id;
              prefs.save();
            }
          }
        }
      }
    }
  }
}
