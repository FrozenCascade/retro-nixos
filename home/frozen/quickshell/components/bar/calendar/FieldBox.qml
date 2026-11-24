import QtQuick
import qs
import "../../../lib/nav.js" as Nav

// A one-line text box in the search-box style (yellow border while the keyboard is in it).
Rectangle {
  id: box

  property alias text: input.text
  property string placeholder: ""
  property alias echoMode: input.echoMode     // TextInput.Password hides what is typed

  signal accepted
  signal escaped
  signal committed          // Enter, or the keyboard leaving the box

  readonly property bool focused: input.activeFocus

  function focusIt() {
    input.forceActiveFocus();
  }

  height: 30
  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: input.activeFocus ? Theme.yellow : Theme.fgDim

  Text {
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
    visible: input.text === ""
    text: box.placeholder
    color: Theme.fgDim
    elide: Text.ElideRight
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 1
  }

  TextInput {
    id: input
    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
    verticalAlignment: TextInput.AlignVCenter
    color: Theme.fg
    selectByMouse: true
    clip: true
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize
    activeFocusOnTab: true
    Keys.onUpPressed: event => Nav.move(input, event, false)
    Keys.onDownPressed: event => Nav.move(input, event, false)
    onActiveFocusChanged: {
      if (activeFocus)
        Nav.reveal(box);
    }
    onAccepted: box.accepted()
    onEditingFinished: box.committed()
    Keys.onEscapePressed: box.escaped()
  }
}
