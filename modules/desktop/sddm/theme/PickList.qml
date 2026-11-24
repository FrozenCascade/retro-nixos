import QtQuick
import "style"

// A titled list of choices in an inset box: the users (switch user) or the sessions (desktop environment).
// The chosen row is pressed in and orange. `model` is one of SDDM's models; `roleName` is the text to show.
Rectangle {
  id: box

  property string title: ""
  property alias model: list.model
  property string roleName: "name"
  property int currentIndex: 0

  signal picked(int index)

  radius: Skin.corner
  color: Skin.inset
  border.width: Skin.borderWidth
  border.color: Skin.fgDim

  Text {
    x: 14
    y: 12
    text: box.title
    color: Skin.fgDim
    font.family: Skin.fontMono
    font.bold: true
    font.pointSize: Skin.fontSize - 2
  }

  ListView {
    id: list
    anchors { fill: parent; topMargin: 38; leftMargin: 10; rightMargin: 10; bottomMargin: 10 }
    clip: true
    spacing: 6
    boundsBehavior: Flickable.StopAtBounds

    delegate: Rectangle {
      required property int index
      required property var model

      readonly property bool chosen: index === box.currentIndex

      width: list.width
      height: 34
      radius: Skin.corner
      color: chosen || mouse.containsMouse ? Skin.bgSel : Skin.bgAlt
      border.width: chosen ? Skin.borderWidth : 0
      border.color: Skin.orange

      Text {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: String(model[box.roleName] || "").toUpperCase()
        color: chosen ? Skin.orange : Skin.fg
        font.family: Skin.fontMono
        font.bold: true
        font.pointSize: Skin.fontSize - 1
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: box.picked(index)
      }
    }
  }
}
