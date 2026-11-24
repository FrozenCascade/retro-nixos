import Quickshell
import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// Screen recording (gpu-screen-recorder). A recording is kept until you SAVE it.
// Also: middle click on the bar's song key, Super+F10, or  qs ipc call studio record toggle.
Flickable {
  id: tab

  contentWidth: width
  contentHeight: col.implicitHeight + 10
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: tab.width
    spacing: 12

    // ---- the big button and the timer ----
    Row {
      spacing: 14
      height: 30

      MiniButton {
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        padX: 30
        danger: StudioRecorder.recording
        text: StudioRecorder.recording ? "STOP" : (StudioRecorder.starting ? "STARTING..." : "RECORD")
        enabled: !StudioRecorder.starting
        onClicked: StudioRecorder.toggle()
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: StudioRecorder.recording ? StudioRecorder.elapsedText : ""
        color: Theme.red
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 4
      }

      // the start delay, beside the button (hidden while recording, when the timer is shown instead)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !StudioRecorder.busy
        text: "DELAY"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: !StudioRecorder.busy
        spacing: 6

        Repeater {
          model: StudioRecorder.delayChoices

          MiniButton {
            required property int modelData

            text: modelData === 0 ? "NONE" : modelData + " SEC"
            active: StudioRecorder.delay === modelData
            onClicked: StudioRecorder.setDelay(modelData)
          }
        }
      }
    }

    Text {
      width: parent.width
      visible: text !== ""
      wrapMode: Text.WordWrap
      text: StudioRecorder.note
      color: Theme.green
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 2
    }

    Row {
      visible: StudioRecorder.canPreview && !StudioRecorder.busy
      spacing: 8

      MiniButton { text: "PREVIEW"; onClicked: StudioRecorder.preview() }
      MiniButton { text: "SAVE"; visible: StudioRecorder.haveFile; onClicked: StudioRecorder.save() }
      MiniButton { text: "SAVE AS"; visible: StudioRecorder.haveFile; onClicked: StudioRecorder.saveAs() }
      MiniButton { text: "DISCARD"; visible: StudioRecorder.haveFile; danger: true; onClicked: StudioRecorder.discard() }
    }

    // ---- what ----
    SectionHead { width: parent.width; text: "WHAT TO RECORD" }

    // the same choices as the CAPTURE tab, except ALL MONITORS (RegionPicker.recordAreas)
    Flow {
      width: parent.width
      spacing: 6

      Repeater {
        model: RegionPicker.recordAreas

        MiniButton {
          required property var modelData

          text: modelData.name
          active: StudioRecorder.target === modelData.id
          onClicked: StudioRecorder.setTarget(modelData.id)
        }
      }
    }

    SectionHead { width: parent.width; text: "FRAMES PER SECOND" }

    Flow {
      width: parent.width
      spacing: 6

      Repeater {
        model: StudioRecorder.fpsChoices

        MiniButton {
          required property int modelData

          text: String(modelData)
          active: StudioRecorder.fps === modelData
          onClicked: StudioRecorder.setFps(modelData)
        }
      }
    }

    SectionHead { width: parent.width; text: "STOP BY ITSELF AFTER" }

    Row {
      spacing: 6

      Repeater {
        model: StudioRecorder.limitChoices

        MiniButton {
          required property int modelData

          text: modelData === 0 ? "NEVER" : modelData + " MIN"
          active: StudioRecorder.limitMinutes === modelData
          onClicked: StudioRecorder.setLimit(modelData)
        }
      }
    }

    // ---- sound ----
    SectionHead { width: parent.width; text: "SOUND (ALL PICKED SOURCES ARE MIXED)" }

    Repeater {
      model: StudioRecorder.audioChoices

      CheckRow {
        required property var modelData

        label: modelData.name
        checked: StudioRecorder.hasAudio(modelData.id)
        onToggled: StudioRecorder.toggleAudio(modelData.id)
      }
    }

    SideButtons { width: parent.width }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "SAVED FILES GO TO ~/Videos/Recordings. A RECORDING YOU DO NOT SAVE IS REPLACED BY THE NEXT ONE."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }
}
