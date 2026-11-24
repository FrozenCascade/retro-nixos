import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// A small playlist player for music files and folders (mpv in the background, see StudioLibrary).
// While it plays it is also a player in the PLAYER tab and on the bar.
Item {
  id: tab

  onVisibleChanged: {
    if (visible)
      StudioLibrary.refreshFolders();
  }

  Column {
    id: top
    width: parent.width
    spacing: 10

    SectionHead { width: parent.width; text: "ADD MUSIC" }

    Row {
      width: parent.width
      spacing: 8

      FieldBox {
        id: path
        width: parent.width - addButton.width - 8
        height: 28
        placeholder: "FOLDER OR FILE (" + StudioLibrary.musicDir.replace(/^.*\/Music$/, "~/Music") + ")"
        onAccepted: tab.addTyped()
        onEscaped: text = ""
      }

      MiniButton {
        id: addButton
        height: 28
        text: "ADD"
        onClicked: tab.addTyped()
      }
    }

    Flow {
      width: parent.width
      spacing: 6

      MiniButton {
        text: "ALL OF ~/MUSIC"
        onClicked: StudioLibrary.add(StudioLibrary.musicDir)
      }

      Repeater {
        model: StudioLibrary.folders

        MiniButton {
          required property string modelData

          text: modelData.split("/").pop().toUpperCase()
          onClicked: StudioLibrary.add(modelData)
        }
      }
    }

    Row {
      spacing: 6

      MiniButton { text: Glyphs.skipPrevious; onClicked: StudioLibrary.send(["playlist-prev"]) }
      MiniButton { text: "PLAY/PAUSE"; onClicked: StudioLibrary.send(["cycle", "pause"]) }
      MiniButton { text: Glyphs.skipNext; onClicked: StudioLibrary.send(["playlist-next"]) }
      MiniButton { text: "SHUFFLE"; onClicked: StudioLibrary.shuffle() }
      MiniButton { text: "REPEAT"; active: StudioLibrary.repeat; onClicked: StudioLibrary.toggleRepeat() }
    }

    Item {
      width: parent.width
      height: 22

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 150
        elide: Text.ElideRight
        text: !StudioLibrary.alive ? "PLAYER OFF. ADD SOMETHING TO START IT." : (StudioLibrary.note !== "" ? StudioLibrary.note : StudioLibrary.playlist.length + " IN THE LIST")
        color: Theme.green
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }

      Row {
        anchors.right: parent.right
        spacing: 6
        MiniButton { text: "CLEAR"; enabled: StudioLibrary.alive; onClicked: StudioLibrary.clear() }
        MiniButton { text: "QUIT"; danger: true; enabled: StudioLibrary.alive; onClicked: StudioLibrary.quit() }
      }
    }
  }

  function addTyped() {
    StudioLibrary.add(path.text !== "" ? path.text : StudioLibrary.musicDir);
    path.text = "";
  }

  // ---- the list ----
  Flickable {
    id: flick
    anchors { left: parent.left; right: parent.right; top: top.bottom; bottom: parent.bottom; topMargin: 6 }
    clip: true
    contentWidth: width
    contentHeight: list.implicitHeight + 4
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: list
      width: flick.width
      spacing: 4

      Repeater {
        model: StudioLibrary.playlist

        Rectangle {
          id: row
          required property var modelData
          required property int index

          width: list.width
          height: 26
          radius: Retro.corner
          color: Retro.inset
          border.width: Retro.borderWidth
          border.color: modelData.current ? Theme.orange : Theme.fgDim

          MouseArea {
            anchors { left: parent.left; right: remove.left; top: parent.top; bottom: parent.bottom }
            cursorShape: Qt.PointingHandCursor
            onClicked: StudioLibrary.playIndex(row.index)
          }

          Text {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52
            elide: Text.ElideRight
            text: (row.index + 1) + "  " + StudioLibrary.nameOf(row.modelData)
            color: row.modelData.current ? Theme.orange : Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 2
          }

          MiniButton {
            id: remove
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            height: 18
            text: "x"
            danger: true
            onClicked: StudioLibrary.removeIndex(row.index)
          }
        }
      }
    }
  }
}
