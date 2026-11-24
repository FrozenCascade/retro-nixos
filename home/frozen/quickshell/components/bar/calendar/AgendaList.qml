import QtQuick
import qs
import qs.components.shared

// What is on one day: holidays, season and moon lines, events and reminders.
// Reminders get length buttons (down to the minute), a bell and a delete button.
Item {
  id: root

  property int dn: 0

  signal edit(string kind, string id)

  readonly property var rows: CalendarStore.agenda(dn)

  Text {
    anchors.centerIn: parent
    visible: root.rows.length === 0
    text: "NOTHING ON THIS DAY    PRESS N TO ADD"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  ListView {
    anchors.fill: parent
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    model: root.rows

    delegate: Item {
      id: row
      required property var modelData
      readonly property bool isReminder: modelData.kind === "reminder"
      readonly property bool hasGlyph: modelData.kind === "moon" || modelData.kind === "phase"
      readonly property color tint: ({ holiday: Theme.green, event: Theme.blue, reminder: Theme.orange, season: Theme.yellow, moon: Theme.fgDim, phase: Theme.yellow })[modelData.kind]

      width: ListView.view.width
      height: isReminder ? 56 : 28

      Rectangle {
        anchors.fill: parent
        radius: Retro.corner
        color: Retro.inset
      }

      Rectangle {
        x: 0
        width: 3
        height: parent.height
        color: row.tint
      }

      Text {
        x: 12
        y: 5
        width: 20
        horizontalAlignment: Text.AlignHCenter
        visible: row.hasGlyph
        text: row.modelData.glyph || ""
        color: row.tint
        font.family: "Weather Icons"
        font.pointSize: Theme.fontSize
      }

      Rectangle {
        x: 18
        y: 11
        width: 7
        height: 7
        visible: !row.hasGlyph
        color: row.tint
        rotation: row.modelData.kind === "season" ? 45 : 0
      }

      Text {
        x: 40
        y: 5
        width: 124
        elide: Text.ElideRight
        text: row.modelData.detail
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }

      Text {
        x: 168
        y: 5
        width: parent.width - 168 - (row.isReminder ? 100 : (row.modelData.kind === "event" ? 66 : 10))
        elide: Text.ElideRight
        text: row.modelData.title
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Row {
        anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 3 }
        spacing: 4
        MiniButton {
          visible: row.isReminder
          text: "\uf0f3"
          active: row.isReminder && row.modelData.notify
          onClicked: CalendarStore.setNotify(row.modelData.id, !row.modelData.notify)
        }
        MiniButton {
          visible: row.isReminder || row.modelData.kind === "event"
          text: "\uf040"
          onClicked: root.edit(row.modelData.kind, row.modelData.id)
        }
        MiniButton {
          visible: row.isReminder || row.modelData.kind === "event"
          text: "\uf1f8"
          danger: true
          onClicked: CalendarStore.removeItem(row.modelData.kind, row.modelData.id, row.modelData.title)
        }
      }

      Row {
        visible: row.isReminder
        x: 12
        y: 30
        spacing: 4
        Text {
          width: 88
          anchors.verticalCenter: parent.verticalCenter
          text: "LENGTH " + (row.modelData.lengthText || "")
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }
        MiniButton { text: "-1"; onClicked: CalendarStore.extendReminder(row.modelData.id, -1) }
        MiniButton { text: "+1"; onClicked: CalendarStore.extendReminder(row.modelData.id, 1) }
        MiniButton { text: "+15"; onClicked: CalendarStore.extendReminder(row.modelData.id, 15) }
        MiniButton { text: "+1H"; onClicked: CalendarStore.extendReminder(row.modelData.id, 60) }
      }
    }
  }
}
