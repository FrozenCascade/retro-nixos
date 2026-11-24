import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools

// One monitor: a bulb, its name, a brightness slider, and how it is controlled (PANEL, DDC or SOFTWARE).
// The laptop panel also gets the button that switches its screen off.
Rectangle {
  id: card

  required property var monitor         // a Quickshell screen

  readonly property string kind: DisplayState.kindOf(monitor.name)
  readonly property real level: DisplayState.levelOf(monitor.name)
  readonly property bool off: kind === "backlight" && DisplayState.laptopHidden

  height: 92
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: DisplayState.current === monitor.name ? Theme.blue : Theme.fgDim

  Text {
    x: 10
    y: 14
    width: 36
    horizontalAlignment: Text.AlignHCenter
    text: DisplayState.bulb(card.level)
    color: card.off ? Theme.fgDim : Theme.yellow
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize + 10
  }

  Text {
    x: 58
    y: 10
    width: card.width - 58 - 110
    elide: Text.ElideRight
    text: card.monitor.name + (card.monitor.model ? "   " + card.monitor.model : "")
    color: Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Text {
    anchors { right: parent.right; rightMargin: 12 }
    y: 10
    text: card.kind === "backlight" ? "PANEL" : (card.kind === "ddc" ? "DDC" : "SOFTWARE")
    color: card.kind === "soft" ? Theme.orange : Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  LineSlider {
    x: 58
    y: 34
    width: card.width - 58 - 76
    value: card.level
    dim: card.off
    enabled: !card.off
    fill: Theme.yellow
    onMoved: v => DisplayState.setBrightness(card.monitor.name, v)
  }

  Text {
    x: card.width - 66
    y: 37
    width: 54
    horizontalAlignment: Text.AlignRight
    text: card.off ? "OFF" : Math.round(card.level * 100) + "%"
    color: card.off ? Theme.red : Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  MiniButton {
    anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 8 }
    visible: card.kind === "backlight" && DisplayState.canHideLaptop
    text: card.off ? "SCREEN ON" : "SCREEN OFF"
    active: card.off
    onClicked: DisplayState.setLaptopHidden(!DisplayState.laptopHidden)
  }
}
