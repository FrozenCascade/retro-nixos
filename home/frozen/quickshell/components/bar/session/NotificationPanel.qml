import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// Past notifications, grouped by app. Each one has: REPOP (show it again as a popup, without sending a
// new notification), COPY, and delete. Click the text to expand a long message.
Item {
  id: panel

  Item {
    id: head
    width: parent.width
    height: 24

    SectionHead {
      anchors { left: parent.left; right: clearAll.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
      text: "NOTIFICATIONS (" + NotifStore.items.length + ")"
    }

    MiniButton {
      id: clearAll
      anchors.right: parent.right
      visible: NotifStore.items.length > 0
      text: "CLEAR ALL"
      onClicked: NotifStore.clear()
    }
  }

  Text {
    anchors.centerIn: parent
    visible: NotifStore.items.length === 0
    text: "NOTHING HERE YET"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  Flickable {
    id: flick
    anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 8 }
    clip: true
    contentWidth: width
    contentHeight: groups.implicitHeight + 6
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: groups
      width: flick.width
      spacing: 12

      Repeater {
        model: NotifStore.groups
        delegate: Column {
          id: group
          required property var modelData
          width: groups.width
          spacing: 6

          // the app: icon, name, how many, and clear just this app
          Item {
            width: parent.width
            height: 24

            Image {
              id: appIcon
              anchors.verticalCenter: parent.verticalCenter
              width: 20
              height: 20
              sourceSize: Qt.size(20, 20)
              fillMode: Image.PreserveAspectFit
              source: NotifStore.iconFor(group.modelData.icon)
            }

            Text {
              x: 28
              width: parent.width - 28 - 90
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              text: group.modelData.app.toUpperCase() + "  (" + group.modelData.items.length + ")"
              color: Theme.yellow
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize - 1
            }

            MiniButton {
              anchors.right: parent.right
              text: "CLEAR"
              onClicked: NotifStore.clearApp(group.modelData.app)
            }
          }

          Repeater {
            model: group.modelData.items
            delegate: Rectangle {
              id: card
              required property var modelData
              property bool expanded: false

              width: group.width
              height: inner.implicitHeight + 16
              radius: Retro.corner
              color: Retro.inset

              Rectangle {
                width: 3
                height: parent.height
                color: card.modelData.urgency === 2 ? Theme.red : Theme.orange
              }

              Column {
                id: inner
                x: 14
                y: 8
                width: parent.width - 22
                spacing: 4

                Item {
                  width: parent.width
                  height: 24

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotifStore.ago(card.modelData.time)
                    color: Theme.fgDim
                    font.family: Theme.fontMono
                    font.bold: true
                    font.pointSize: Theme.fontSize - 2
                  }

                  Row {
                    anchors.right: parent.right
                    spacing: 4
                    MiniButton { text: "REPOP"; onClicked: NotifStore.repop(card.modelData) }
                    MiniButton { text: "COPY"; onClicked: NotifStore.copy(card.modelData) }
                    MiniButton { text: "x"; danger: true; onClicked: NotifStore.remove(card.modelData.id) }
                  }
                }

                Text {
                  width: parent.width
                  wrapMode: Text.Wrap
                  maximumLineCount: card.expanded ? 6 : 2
                  elide: Text.ElideRight
                  text: card.modelData.summary
                  color: Theme.fg
                  font.family: Theme.fontMono
                  font.bold: true
                  font.pointSize: Theme.fontSize - 1
                }

                Text {
                  visible: card.modelData.body !== ""
                  width: parent.width
                  wrapMode: Text.Wrap
                  maximumLineCount: card.expanded ? 14 : 3
                  elide: Text.ElideRight
                  text: card.modelData.body
                  color: Theme.fgDim
                  font.family: Theme.fontMono
                  font.pointSize: Theme.fontSize - 2
                }
              }

              MouseArea {
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 34; bottom: parent.bottom }
                cursorShape: Qt.PointingHandCursor
                onClicked: card.expanded = !card.expanded
              }
            }
          }
        }
      }
    }
  }
}
