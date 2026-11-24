import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// One sound device, laid out like KDE's audio widget: icon, name, slider with percentage, and the
// buttons for MAX (volume up to 150%), mute and "default device". The microphone also gets TEST.
Rectangle {
  id: card

  required property var node
  property bool showTest: false

  readonly property var audio: node ? node.audio : null
  readonly property bool isDefault: AudioState.isDefault(node)
  readonly property bool boosted: !!node && !!AudioState.boosted[node.id]

  height: 92
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: isDefault ? Theme.blue : Theme.fgDim

  // middle click anywhere on the card mutes this device (buttons and the slider ignore the middle button)
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onClicked: {
      if (card.audio)
        card.audio.muted = !card.audio.muted;
    }
  }

  ThemeIcon {
    x: 10
    y: 12
    width: 36
    height: 36
    category: "devices"
    fallback: "audio-card"
    name: AudioState.deviceIcon(card.node)
  }

  Text {
    x: 58
    y: 10
    width: card.width - 70
    elide: Text.ElideRight
    text: AudioState.label(card.node)
    color: card.isDefault ? Theme.fg : Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  LineSlider {
    x: 58
    y: 32
    width: card.width - 58 - 76
    value: card.audio ? card.audio.volume : 0
    maxValue: card.node ? AudioState.maxOf(card.node.id) : 1.0
    dim: card.audio ? card.audio.muted : false
    onMuteKey: {
      if (card.audio)
        card.audio.muted = !card.audio.muted;
    }
    onMoved: v => {
      if (card.audio) {
        card.audio.volume = v;
        if (card.node.isSink)
          Sounds.volumeTick();
      }
    }
  }

  Text {
    x: card.width - 66
    y: 35
    width: 54
    horizontalAlignment: Text.AlignRight
    text: card.audio ? (card.audio.muted ? "MUTED" : Math.round(card.audio.volume * 100) + "%") : ""
    color: card.audio && card.audio.muted ? Theme.red : (card.audio && card.audio.volume > 1.001 ? Theme.orange : Theme.fg)
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Row {
    anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 8 }
    spacing: 6

    MiniButton {
      visible: card.showTest
      text: AudioState.testState === "idle" ? "TEST..." : (AudioState.testState === "recording" ? "RECORDING" : "PLAYING")
      active: AudioState.testState !== "idle"
      onClicked: AudioState.micTest()
    }

    MiniButton {
      text: "MAX"
      active: card.boosted
      onClicked: AudioState.toggleBoost(card.node.id, card.audio)
    }

    MiniButton {
      text: "MUTE"
      active: card.audio ? card.audio.muted : false
      onClicked: {
        if (card.audio)
          card.audio.muted = !card.audio.muted;
      }
    }

    MiniButton {
      text: "\u2605 DEFAULT"
      active: card.isDefault
      onClicked: AudioState.makeDefault(card.node)
    }
  }
}
