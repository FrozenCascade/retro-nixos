import QtQuick
import qs
import qs.components.shared

// The small buttons at the right end of a list row: [copy] [star] [delete].
// Switch off the ones a row does not need.
Row {
  id: actions

  property bool showCopy: true
  property bool showPin: true
  property bool showDelete: true
  property bool pinned: false

  signal copyClicked
  signal pinClicked
  signal deleteClicked

  // true while the pointer is on any of the buttons (so a row can keep them showing)
  readonly property bool hovered: copyButton.hovered || pinButton.hovered || deleteButton.hovered

  spacing: 4

  MiniButton {
    id: copyButton
    visible: actions.showCopy
    text: "\uf0c5"
    onClicked: actions.copyClicked()
  }

  MiniButton {
    id: pinButton
    visible: actions.showPin
    text: actions.pinned ? "★" : "☆"
    active: actions.pinned
    onClicked: actions.pinClicked()
  }

  MiniButton {
    id: deleteButton
    visible: actions.showDelete
    text: "\uf1f8"
    danger: true
    onClicked: actions.deleteClicked()
  }
}
