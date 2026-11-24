import QtQuick
import qs
import qs.components.shared

// Your fingerprints. Click an empty finger to add it (the reader asks for several touches); click a
// marked one to remove it. What is saved here opens the lock screen and answers sudo's password question.
Rectangle {
  id: panel

  height: col.implicitHeight + 24
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  Column {
    id: col
    x: 12
    y: 12
    width: panel.width - 24
    spacing: 8

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: !FingerprintState.available ? "NO FINGERPRINT READER FOUND"
        : (FingerprintState.enrolling !== "" || FingerprintState.message !== "") ? FingerprintState.message
        : (FingerprintState.enrolled.length === 0 ? "NO FINGERPRINTS SAVED. CLICK A FINGER TO ADD IT." : "MARKED FINGERS ARE SAVED. CLICK ONE TO REMOVE IT.")
      color: FingerprintState.enrolling !== "" ? Theme.yellow : Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 2
    }

    Repeater {
      model: FingerprintState.hands

      Row {
        id: handRow
        required property var modelData

        spacing: 6

        Text {
          width: 52
          anchors.verticalCenter: parent.verticalCenter
          text: handRow.modelData.name
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        Repeater {
          model: handRow.modelData.fingers

          MiniButton {
            required property var modelData

            text: modelData.label
            active: FingerprintState.has(modelData.id) || FingerprintState.enrolling === modelData.id
            enabled: FingerprintState.available && (FingerprintState.enrolling === "" || FingerprintState.enrolling === modelData.id)
            onClicked: FingerprintState.has(modelData.id) ? FingerprintState.remove(modelData.id) : FingerprintState.enroll(modelData.id)
          }
        }
      }
    }

    MiniButton {
      visible: FingerprintState.enrolling !== ""
      text: "CANCEL"
      onClicked: FingerprintState.cancel()
    }
  }
}
