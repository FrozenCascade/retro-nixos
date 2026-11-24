import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// Screenshots. A capture always goes to the clipboard; SAVE and ANNOTATE come afterwards
// (here, or as buttons on the notification). The work is done by studio-shot (studio.nix).
Item {
  id: tab

  readonly property bool haveShot: StudioState.lastShot !== ""

  Column {
    width: parent.width
    spacing: 12

    // the capture button and its delay at the top, like the RECORD tab
    Row {
      spacing: 14
      height: 30

      MiniButton {
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        padX: 30
        text: StudioState.shotBusy ? "WORKING..." : "CAPTURE"
        enabled: !StudioState.shotBusy
        onClicked: StudioState.capture(StudioState.shotMode, StudioState.shotDelay)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "DELAY"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
          model: StudioState.shotDelays

          MiniButton {
            required property int modelData

            text: modelData === 0 ? "NONE" : modelData + " SEC"
            active: StudioState.shotDelay === modelData
            onClicked: StudioState.setShotDelay(modelData)
          }
        }
      }
    }

    SectionHead { width: parent.width; text: "WHAT TO CAPTURE" }

    Flow {
      width: parent.width
      spacing: 6

      Repeater {
        model: RegionPicker.areas

        MiniButton {
          required property var modelData

          text: modelData.name
          active: StudioState.shotMode === modelData.id
          onClicked: StudioState.setShotMode(modelData.id)
        }
      }
    }

    SectionHead { width: parent.width; text: "LAST CAPTURE" }

    Rectangle {
      width: parent.width
      height: 214     // the preview takes whatever height the rows above leave free
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: Theme.fgDim
      clip: true

      Image {
        id: shot
        anchors.fill: parent
        anchors.margins: 4
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        visible: tab.haveShot
        source: tab.haveShot ? "file://" + StudioState.lastShot + "#" + StudioState.shotCount : ""
      }

      // hold the mouse on the picture to see it at full size around the pointer (drag to look around)
      MouseArea {
        id: look
        anchors.fill: parent
        enabled: tab.haveShot
        cursorShape: Qt.CrossCursor
      }

      Item {
        id: loupe
        anchors.fill: shot
        clip: true
        visible: look.pressed && shot.paintedWidth > 0

        // real pixels, but never less than twice the preview
        readonly property real zoom: Math.max(2, shot.sourceSize.width / shot.paintedWidth)
        // the pointer's place on the picture, from 0 to 1
        readonly property real fx: Math.max(0, Math.min(1, (look.mouseX - shot.x - (shot.width - shot.paintedWidth) / 2) / shot.paintedWidth))
        readonly property real fy: Math.max(0, Math.min(1, (look.mouseY - shot.y - (shot.height - shot.paintedHeight) / 2) / shot.paintedHeight))

        Image {
          width: shot.paintedWidth * loupe.zoom
          height: shot.paintedHeight * loupe.zoom
          x: look.mouseX - shot.x - loupe.fx * width
          y: look.mouseY - shot.y - loupe.fy * height
          cache: false
          asynchronous: true
          source: shot.source
        }
      }

      // the capture's status line ("COPIED", "SAVED ...") sits on the preview now
      Text {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
        elide: Text.ElideRight
        text: StudioState.shotNote
        color: Theme.green
        style: Text.Outline
        styleColor: Retro.inset
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }

      Text {
        anchors.centerIn: parent
        visible: !tab.haveShot
        text: "NOTHING CAPTURED YET"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }

    Flow {
      width: parent.width
      spacing: 8

      MiniButton { text: "SAVE"; enabled: tab.haveShot; onClicked: StudioState.saveShot() }
      MiniButton { text: "SAVE AS"; enabled: tab.haveShot; onClicked: StudioState.saveShotAs() }
      MiniButton { text: "ANNOTATE"; enabled: tab.haveShot; onClicked: StudioState.annotateShot() }
      MiniButton { text: "COPY AGAIN"; enabled: tab.haveShot; onClicked: StudioState.copyShot() }
      MiniButton { text: "IMPORT"; onClicked: StudioState.importShot() }

      // two clicks: DELETE asks, SURE? does it (it asks again after three seconds)
      MiniButton {
        id: del

        property bool sure: false

        text: sure ? "SURE?" : "DELETE"
        active: sure
        enabled: tab.haveShot
        onEnabledChanged: sure = false
        onClicked: {
          if (sure) {
            sure = false;
            StudioState.deleteShot();
          } else {
            sure = true;
            sureTimer.restart();
          }
        }

        Timer {
          id: sureTimer
          interval: 3000
          onTriggered: del.sure = false
        }
      }
    }

    Item {
      width: parent.width
      height: 30

      ColorPickRow {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "KEYS: PRINT = REGION, SHIFT+PRINT = ALL MONITORS, SUPER+PRINT = WINDOW. SAVED FILES GO TO ~/Pictures/Screenshots. HOLD THE MOUSE ON THE PICTURE TO ZOOM."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }
}
