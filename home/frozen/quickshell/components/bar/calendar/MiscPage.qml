import QtQuick
import qs
import qs.components.shared
import "../../../lib/commands.js" as Commands

// The third tab, "MISC": handy commands (click to copy, listed in lib/commands.js) and how old the flake inputs are.
Item {
  id: page

  property bool active: false

  function reset() {
    flick.contentY = 0;
    FlakeAge.refresh();
  }

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.rightMargin: 10
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 10
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: flick.width
      spacing: 12

      SectionHead { width: parent.width; text: "INPUTS" }

      Rectangle {
        width: parent.width
        height: 104
        radius: Retro.corner
        color: Retro.inset
        border.width: Retro.borderWidth
        border.color: FlakeAge.overdue ? Theme.orange : Theme.fgDim

        Text { x: 12; y: 8; text: "SINCE THE LAST FLAKE UPDATE"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 2 }
        Text { x: 12; y: 26; text: FlakeAge.ageText; color: FlakeAge.overdue ? Theme.orange : Theme.fg; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize + 5 }
        Text {
          anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
          text: !FlakeAge.known ? "" : (FlakeAge.overdue ? "OVERDUE" : "ON TIME")
          color: FlakeAge.overdue ? Theme.red : Theme.green
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
        Rectangle {
          x: 12
          y: 66
          width: parent.width - 24
          height: 8
          color: Theme.bg
          Rectangle {
            width: parent.width * FlakeAge.fraction
            height: parent.height
            color: FlakeAge.fraction >= 1 ? Theme.red : (FlakeAge.fraction > 0.75 ? Theme.yellow : Theme.green)
          }
        }
        Text { x: 12; y: 82; text: FlakeAge.whenText + "   (LIMIT " + FlakeAge.limitDays + " DAYS)"; color: Theme.fgDim; font.family: Theme.fontMono; font.pointSize: Theme.fontSize - 2 }
      }

      Item {
        width: parent.width
        height: 24
        CheckRow {
          label: "NOTIFY AT LOGIN WHEN OVERDUE"
          checked: CalendarStore.settings.flakeNag
          onToggled: v => CalendarStore.setSetting("flakeNag", v)
        }
        MiniButton { anchors.right: parent.right; text: "TEST"; onClicked: FlakeAge.testNow() }
      }

      Row {
        spacing: 8
        height: 24
        Text { anchors.verticalCenter: parent.verticalCenter; text: "OVERDUE AFTER"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
        NumberField { anchors.verticalCenter: parent.verticalCenter; value: CalendarStore.settings.flakeNagDays; from: 1; to: 365; bigStep: 7; onEdited: v => CalendarStore.setSetting("flakeNagDays", v) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "DAYS"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
      }

      // the commands come from lib/commands.js
      Repeater {
        model: Commands.groups

        Column {
          id: group
          required property var modelData

          width: col.width
          spacing: 12

          SectionHead { width: parent.width; text: group.modelData.name }

          Repeater {
            model: group.modelData.items

            CommandBlock {
              required property var modelData

              width: group.width
              title: modelData.title
              lines: modelData.lines
            }
          }
        }
      }
    }
  }

  WheelScroll {
    anchors.fill: flick
    view: flick
    notchPixels: 60
  }

  RetroScrollBar {
    target: flick
    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
  }
}
