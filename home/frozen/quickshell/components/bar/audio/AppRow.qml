import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// One application's volume: its icon, name, slider, MAX and mute. After it stops it stays for a few
// seconds (dimmed) before it disappears, so the list does not jump under your mouse.
Rectangle {
  id: row

  required property var entry           // from AudioState.playRows / recRows

  readonly property var audio: entry.node ? entry.node.audio : null
  readonly property bool ended: entry.goneAt > 0
  readonly property real level: audio ? audio.volume : entry.vol
  readonly property bool muted: audio ? audio.muted : entry.muted
  readonly property bool boosted: !!AudioState.boosted[entry.key]

  height: 58
  radius: Retro.corner
  color: Retro.inset
  opacity: ended ? 0.45 : 1
  Behavior on opacity { NumberAnimation { duration: 300 } }

  // middle click anywhere on the row mutes this app
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    enabled: !row.ended
    onClicked: {
      if (row.audio)
        row.audio.muted = !row.audio.muted;
    }
  }

  ThemeIcon {
    x: 10
    y: 11
    width: 36
    height: 36
    category: "apps"
    fallback: "audio-x-generic"
    name: row.entry.icon
  }

  Text {
    x: 58
    y: 7
    width: row.width - 140
    elide: Text.ElideRight
    text: row.entry.name + (row.ended ? "   (STOPPED)" : "")
    color: Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  LineSlider {
    x: 58
    y: 28
    width: row.width - 58 - 214
    enabled: !row.ended
    value: row.level
    maxValue: AudioState.maxOf(row.entry.key)
    dim: row.muted
    onMuteKey: {
      if (row.audio)
        row.audio.muted = !row.audio.muted;
    }
    onMoved: v => {
      if (row.audio)
        row.audio.volume = v;
    }
  }

  Text {
    x: row.width - 200
    y: 31
    width: 50
    horizontalAlignment: Text.AlignRight
    text: row.muted ? "MUTED" : Math.round(row.level * 100) + "%"
    color: row.muted ? Theme.red : (row.level > 1.001 ? Theme.orange : Theme.fg)
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Row {
    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
    spacing: 6

    MiniButton {
      enabled: !row.ended
      text: "MAX"
      active: row.boosted
      onClicked: AudioState.toggleBoost(row.entry.key, row.audio)
    }

    MiniButton {
      enabled: !row.ended
      text: "MUTE"
      active: row.muted
      onClicked: {
        if (row.audio)
          row.audio.muted = !row.audio.muted;
      }
    }
  }
}
