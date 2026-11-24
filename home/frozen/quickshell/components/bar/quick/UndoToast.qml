import QtQuick
import qs
import qs.components.shared

// "Deleted ... Undo" at the bottom of the quick window, with a time bar that runs down.
Rectangle {
  id: toast

  property real remaining: 1

  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.orange

  NumberAnimation {
    id: countdown
    target: toast
    property: "remaining"
    from: 1
    to: 0
    duration: QuickUndo.seconds * 1000
  }

  Connections {
    target: QuickUndo

    function onPendingChanged() {
      if (QuickUndo.pending !== null)
        countdown.restart();
    }
  }

  Text {
    anchors {
      left: parent.left
      right: undoButton.left
      verticalCenter: parent.verticalCenter
      verticalCenterOffset: -1
      leftMargin: 10
      rightMargin: 10
    }
    elide: Text.ElideRight
    text: "DELETED  " + (QuickUndo.pending ? QuickUndo.pending.label : "")
    color: Theme.fg
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  MiniButton {
    id: undoButton
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
      verticalCenterOffset: -1
      rightMargin: 8
    }
    text: "UNDO  Ctrl+Z"
    onClicked: QuickUndo.undo()
  }

  // time bar
  Rectangle {
    x: 4
    y: parent.height - 7
    width: (parent.width - 8) * toast.remaining
    height: 3
    color: Theme.orange
  }
}
