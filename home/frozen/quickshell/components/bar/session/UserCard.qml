import QtQuick
import qs
import qs.components.shared

// You: your icon, name, uptime, and the button that opens the icon chooser.
Rectangle {
  id: card

  property bool choosing: false

  property bool fingerprinting: false

  signal chooseClicked
  signal fingerprintClicked

  height: 72
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  Rectangle {
    id: frame
    x: 10
    y: 8
    width: 54
    height: 54
    radius: Retro.corner
    color: Theme.bgAlt
    border.width: Retro.borderWidth
    border.color: Theme.fg
    clip: true

    Image {
      id: avatar
      anchors.fill: parent
      anchors.margins: 2
      cache: false
      asynchronous: true
      fillMode: Image.PreserveAspectCrop
      source: SessionState.avatarUrl
    }

    Text {
      anchors.centerIn: parent
      visible: avatar.status !== Image.Ready
      text: SessionState.user.charAt(0).toUpperCase()
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize + 8
    }
  }

  Text {
    x: 76
    y: 14
    width: card.width - 76 - 250
    elide: Text.ElideRight
    text: SessionState.user
    color: Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize + 2
  }

  Text {
    x: 76
    y: 38
    width: card.width - 76 - 250
    elide: Text.ElideRight
    text: SessionState.uptime !== "" ? "UP " + SessionState.uptime.toUpperCase() : ""
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 2
  }

  MiniButton {
    id: iconButton
    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
    text: "CHANGE ICON"
    active: card.choosing
    onClicked: card.chooseClicked()
  }

  MiniButton {
    anchors { right: iconButton.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
    text: "FINGERPRINT"
    active: card.fingerprinting
    onClicked: card.fingerprintClicked()
  }
}
