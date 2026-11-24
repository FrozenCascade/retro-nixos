import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import qs.components.bar.calendar
import "../../../lib/display.js" as Disp

// The NIGHT LIGHT tab: a warm tint through hyprsunset. A switch, the temperature, and an optional
// schedule (it may cross midnight, 20:00 to 07:00).
Flickable {
  id: flick

  // ---- edit here ----
  // night = while night light is on (by the switch or the schedule), day = the rest of the time.
  // Keep day above night. Set day to 6500 for no tint in the daytime.
  readonly property var tints: [
    { title: "NIGHT TINT", key: "nightTemp", presets: [3400, 4000, 4500, 5500] },
    { title: "DAY TINT", key: "dayTemp", presets: [4500, 5500, 6000, 6500] }
  ]

  readonly property real span: DisplayState.nightMax - DisplayState.nightMin

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 10

    Tile {
      width: parent.width
      glyph: Glyphs.moon
      label: "NIGHT LIGHT"
      sub: DisplayState.nightSchedule ? (DisplayState.nightWanted ? "ON BY SCHEDULE" : "WAITING FOR SCHEDULE") : (DisplayState.nightOn ? "ON" : "OFF")
      active: DisplayState.nightWanted
      onActivated: {
        // the switch always wins: it also turns the schedule off
        const wasOn = DisplayState.nightWanted;
        DisplayState.nightSchedule = false;
        DisplayState.nightOn = !wasOn;
      }
    }

    // one slider and its presets per tint. 6500K is no tint at all.
    Repeater {
      model: flick.tints

      Column {
        id: tint

        required property var modelData
        readonly property int kelvin: DisplayState[modelData.key]

        width: col.width
        spacing: 8

        SectionHead { width: parent.width; text: tint.modelData.title }

        Item {
          width: parent.width
          height: 24

          LineSlider {
            width: parent.width - 80
            anchors.verticalCenter: parent.verticalCenter
            value: (tint.kelvin - DisplayState.nightMin) / flick.span
            step: 0.05
            fill: Theme.orange
            onMoved: v => DisplayState[tint.modelData.key] = Math.round((DisplayState.nightMin + v * flick.span) / 50) * 50
          }

          Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: tint.kelvin + "K"
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }
        }

        Row {
          spacing: 6

          Repeater {
            model: tint.modelData.presets

            MiniButton {
              required property int modelData
              text: modelData + "K"
              active: tint.kelvin === modelData
              onClicked: DisplayState[tint.modelData.key] = modelData
            }
          }
        }
      }
    }

    SectionHead { width: parent.width; text: "SCHEDULE" }

    CheckRow {
      label: "TURN ON AND OFF BY THE CLOCK"
      checked: DisplayState.nightSchedule
      onToggled: value => DisplayState.nightSchedule = value
    }

    Row {
      spacing: 10
      opacity: DisplayState.nightSchedule ? 1 : 0.5

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "FROM"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      FieldBox {
        id: fromBox
        width: 76
        placeholder: "20:00"
        text: DisplayState.nightFrom
        border.color: Disp.minutesOf(text) < 0 ? Theme.red : (focused ? Theme.yellow : Theme.fgDim)
        onCommitted: {
          if (Disp.minutesOf(text) >= 0)
            DisplayState.nightFrom = text.trim();
          else
            text = DisplayState.nightFrom;
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "TO"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      FieldBox {
        id: toBox
        width: 76
        placeholder: "07:00"
        text: DisplayState.nightTo
        border.color: Disp.minutesOf(text) < 0 ? Theme.red : (focused ? Theme.yellow : Theme.fgDim)
        onCommitted: {
          if (Disp.minutesOf(text) >= 0)
            DisplayState.nightTo = text.trim();
          else
            text = DisplayState.nightTo;
        }
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "TIMES ARE 24 HOUR, HH:MM. THE TINT NEEDS THE HYPRSUNSET SERVICE (SET UP IN THE HOME MANAGER CONFIG)."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }
}
