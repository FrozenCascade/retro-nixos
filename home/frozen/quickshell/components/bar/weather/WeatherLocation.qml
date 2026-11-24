import QtQuick
import qs

// The place picker: search for a place, or pick one you saved.
Item {
  id: panel

  signal done

  onVisibleChanged: {
    if (visible) {
      field.text = "";
      Weather.results = [];
      field.forceActiveFocus();
    }
  }

  Flickable {
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: 8

      Text {
        text: "SEARCH FOR A PLACE (PRESS ENTER)"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      // search box
      Rectangle {
        width: parent.width
        height: 34
        radius: 3
        color: Qt.rgba(0, 0, 0, 0.35)
        border.color: field.activeFocus ? Theme.yellow : Theme.fgDim
        border.width: Retro.borderWidth

        Text {
          id: prompt
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 10
          }
          text: ">_"
          color: Theme.yellow
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 1
        }

        TextInput {
          id: field
          anchors {
            left: prompt.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 10
          }
          verticalAlignment: TextInput.AlignVCenter
          color: Theme.fg
          selectByMouse: true
          clip: true
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize + 1

          onAccepted: Weather.search(text)
        }
      }

      Text {
        visible: Weather.searching
        text: "SEARCHING..."
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 1
      }

      // search results
      Repeater {
        model: Weather.results

        Item {
          id: result
          required property var modelData

          width: column.width
          height: 34

          Rectangle {
            x: 2
            y: 2
            width: parent.width
            height: parent.height
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.6)
            visible: !resultMouse.pressed
          }

          Rectangle {
            x: resultMouse.pressed ? 2 : 0
            y: resultMouse.pressed ? 2 : 0
            width: parent.width
            height: parent.height
            radius: 3
            color: resultMouse.containsMouse ? Theme.bgSel : Theme.bgAlt

            Text {
              anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
              }
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              text: result.modelData.name + (result.modelData.detail ? ",  " + result.modelData.detail : "")
              color: Theme.fg
              font.family: Theme.fontSans
              font.bold: true
              font.pointSize: Theme.fontSize
            }
          }

          MouseArea {
            id: resultMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
              Weather.chooseResult(result.modelData);
              panel.done();
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 2
        color: Theme.fgDim
      }

      Text {
        text: "SAVED PLACES"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Text {
        visible: Weather.places.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        text: "NONE YET. PICK A SEARCH RESULT TO SAVE IT HERE."
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }

      Repeater {
        model: Weather.places

        Item {
          id: place
          required property var modelData
          required property int index

          width: column.width
          height: 34

          Rectangle {
            x: 2
            y: 2
            width: parent.width
            height: parent.height
            radius: 3
            color: Qt.rgba(0, 0, 0, 0.6)
            visible: !placeMouse.pressed
          }

          Rectangle {
            x: placeMouse.pressed ? 2 : 0
            y: placeMouse.pressed ? 2 : 0
            width: parent.width
            height: parent.height
            radius: 3
            color: placeMouse.containsMouse ? Theme.bgSel : Theme.bgAlt
            border.width: place.modelData.name === Weather.locationName ? 2 : 0
            border.color: Theme.aqua

            Text {
              anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 40
              }
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              text: place.modelData.name
              color: Theme.fg
              font.family: Theme.fontSans
              font.bold: true
              font.pointSize: Theme.fontSize
            }
          }

          MouseArea {
            id: placeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
              Weather.setLocation(place.modelData.name, place.modelData.latitude, place.modelData.longitude);
              panel.done();
            }
          }

          // delete this saved place
          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
              rightMargin: 12
            }
            text: "x"
            color: removeMouse.containsMouse ? Theme.red : Theme.fgDim
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize + 1

            MouseArea {
              id: removeMouse
              anchors {
                fill: parent
                margins: -6
              }
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Weather.removePlace(place.index)
            }
          }
        }
      }
    }
  }
}
