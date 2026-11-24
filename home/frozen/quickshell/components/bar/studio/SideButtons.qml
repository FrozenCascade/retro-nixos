import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// What the two side mouse buttons do (the choices are StudioState.sideChoices).
Column {
  id: root

  spacing: 8

  SectionHead { width: parent.width; text: "SIDE MOUSE BUTTONS" }

  Repeater {
    model: [4, 5]

    Column {
      id: side
      required property int modelData

      width: root.width
      spacing: 6

      Text {
        text: "BUTTON " + side.modelData + (side.modelData === 4 ? " (BACK)" : " (FORWARD)")
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Flow {
        width: parent.width
        spacing: 6

        Repeater {
          model: StudioState.sideChoices

          MiniButton {
            required property var modelData

            text: modelData.name
            active: StudioState.sideActions["button" + side.modelData] === modelData.id
            onClicked: StudioState.setSideAction(side.modelData, modelData.id)
          }
        }
      }
    }
  }
}
