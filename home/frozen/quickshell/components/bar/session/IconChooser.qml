import QtQuick
import qs

// Pick a picture from ~/Pictures to be your user icon (copied to ~/.face, which KDE and SDDM read).
Rectangle {
  id: chooser

  signal picked

  height: 150
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  Text {
    x: 12
    y: 8
    text: "PICK A PICTURE FROM ~/PICTURES/WALLPAPERS"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  Text {
    anchors.centerIn: parent
    visible: SessionState.pictures.length === 0
    text: "NO PICTURES FOUND"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 1
  }

  Flickable {
    x: 10
    y: 28
    width: parent.width - 20
    height: parent.height - 36
    clip: true
    contentWidth: width
    contentHeight: flow.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Flow {
      id: flow
      width: parent.width
      spacing: 6

      Repeater {
        model: SessionState.pictures
        delegate: Rectangle {
          required property string modelData
          width: 52
          height: 52
          radius: Retro.corner
          color: Theme.bgAlt
          border.width: 2
          border.color: tileMouse.containsMouse ? Theme.orange : Theme.fgDim
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: 2
            asynchronous: true
            sourceSize: Qt.size(104, 104)
            fillMode: Image.PreserveAspectCrop
            source: "file://" + parent.modelData
          }

          MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              SessionState.setAvatar(parent.modelData);
              chooser.picked();
            }
          }
        }
      }
    }
  }
}
