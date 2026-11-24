import QtQuick
import qs
import qs.components.shared

// "Delete all?" asked on its own, so a delete-all can never happen by accident.
Rectangle {
  id: strip

  property string what: ""
  signal yes
  signal no

  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.red

  Text {
    anchors {
      left: parent.left
      right: yesButton.left
      verticalCenter: parent.verticalCenter
      leftMargin: 10
      rightMargin: 10
    }
    elide: Text.ElideRight
    text: "DELETE " + strip.what + "?  THIS CANNOT BE UNDONE."
    color: Theme.red
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  MiniButton {
    id: yesButton
    anchors {
      right: noButton.left
      verticalCenter: parent.verticalCenter
      rightMargin: 8
    }
    text: "YES"
    danger: true
    onClicked: strip.yes()
  }

  MiniButton {
    id: noButton
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
      rightMargin: 8
    }
    text: "NO"
    onClicked: strip.no()
  }
}
