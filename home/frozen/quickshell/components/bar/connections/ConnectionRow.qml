import QtQuick
import qs

// One line in a connections list: an icon, a title, a small second line, and buttons on the right.
// Every list in the Connections window (networks, Bluetooth devices, VPNs, phones) is made of these.
// Put MiniButtons inside it and they land in the button row.
Rectangle {
  id: row

  property string glyph: ""
  property color glyphTint: Theme.fg
  property string title: ""
  property string sub: ""
  property color subTint: Theme.fgDim
  property bool highlight: false        // blue outline: connected, active or selected
  property bool dim: false

  default property alias actions: buttons.data
  signal clicked

  height: 56
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: highlight ? Theme.blue : Theme.fgDim
  opacity: dim ? 0.55 : 1

  // under the buttons, so a click on empty space selects the row
  MouseArea {
    anchors.fill: parent
    onClicked: row.clicked()
  }

  Text {
    x: 10
    anchors.verticalCenter: parent.verticalCenter
    width: 30
    horizontalAlignment: Text.AlignHCenter
    text: row.glyph
    color: row.glyphTint
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize + 6
  }

  Column {
    x: 52
    anchors.verticalCenter: parent.verticalCenter
    width: row.width - 52 - buttons.width - 20
    spacing: 2

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: row.title
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Text {
      visible: row.sub !== ""
      width: parent.width
      elide: Text.ElideRight
      text: row.sub
      color: row.subTint
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }

  Row {
    id: buttons
    anchors {
      right: parent.right
      rightMargin: 10
      verticalCenter: parent.verticalCenter
    }
    spacing: 6
  }
}
