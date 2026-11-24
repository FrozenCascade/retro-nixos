import QtQuick
import qs

// A retro inset card with a small gray title. Put the card's content inside it.
Rectangle {
  id: card

  property string title: ""
  default property alias content: body.data

  implicitHeight: body.y + body.implicitHeight + 12

  radius: 3
  color: Qt.rgba(0, 0, 0, 0.35)
  border.color: Theme.fgDim
  border.width: Retro.borderWidth

  Text {
    x: 10
    y: 8
    text: card.title
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  Column {
    id: body
    x: 10
    y: 28
    width: parent.width - 20
    spacing: 6
  }
}
