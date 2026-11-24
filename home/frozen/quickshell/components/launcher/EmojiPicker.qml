import Quickshell
import QtQuick
import qs
import "../../lib/emoji.js" as Emoji

// The launcher's emoji search. Type ":" and a name (":fire"). Several names at once ":fire heart smile"
// build one string: the best match for every name but the last, plus the pick for the last one.
// Up / Down choose the pick, Enter or a click copies the whole string.
Rectangle {
  id: root

  property string query: ""                 // the launcher's search text
  readonly property bool active: query.startsWith(":")

  readonly property var words: Emoji.terms(query.slice(1))
  readonly property var matches: words.length > 0 ? Emoji.find(words[words.length - 1], 120) : []
  property int picked: 0

  // everything before the last name uses its best match
  readonly property string lead: {
    let s = "";
    for (let i = 0; i < words.length - 1; i++) {
      const found = Emoji.find(words[i], 1);
      if (found.length > 0)
        s += found[0];
    }
    return s;
  }

  function stringFor(index) {
    return lead + (index >= 0 && index < matches.length ? matches[index] : "");
  }

  signal copied

  function next() {
    if (picked < matches.length - 1)
      picked += 1;
  }

  function previous() {
    if (picked > 0)
      picked -= 1;
  }

  function accept(index) {
    const text = stringFor(index === undefined ? picked : index);
    if (text === "")
      return;
    Quickshell.execDetached([Tools.wlCopy, text]);
    copied();
  }

  onMatchesChanged: picked = 0

  color: Theme.bg

  // swallow clicks on empty areas
  MouseArea {
    anchors.fill: parent
  }

  // ---- what will be copied ----
  Rectangle {
    id: card
    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 0 }
    height: 64
    radius: Retro.corner
    color: Retro.inset
    border.color: Theme.yellow
    border.width: Retro.borderWidth

    Text {
      anchors { left: parent.left; right: hint.left; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 8 }
      elide: Text.ElideRight
      text: root.stringFor(root.picked) !== "" ? root.stringFor(root.picked) : "TYPE A NAME, LIKE :FIRE HEART"
      color: root.stringFor(root.picked) !== "" ? Theme.fg : Theme.fgDim
      font.family: root.stringFor(root.picked) !== "" ? "Noto Color Emoji" : Theme.fontMono
      font.bold: true
      font.pointSize: root.stringFor(root.picked) !== "" ? Theme.fontSize + 9 : Theme.fontSize - 1
    }

    Text {
      id: hint
      anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 14 }
      text: "ENTER = COPY"
      color: Theme.yellow
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.accept()
    }
  }

  // ---- matches for the name being typed ----
  GridView {
    id: grid
    anchors { left: parent.left; right: parent.right; top: card.bottom; bottom: parent.bottom; topMargin: 8 }
    clip: true
    cellWidth: 48
    cellHeight: 48
    model: root.matches
    currentIndex: root.picked
    boundsBehavior: Flickable.StopAtBounds
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

    delegate: Item {
      required property string modelData
      required property int index

      width: grid.cellWidth
      height: grid.cellHeight

      Rectangle {
        anchors { fill: parent; margins: 2 }
        radius: Retro.corner
        color: hit.containsMouse || root.picked === index ? Theme.bgSel : "transparent"
        border.width: root.picked === index ? Retro.borderWidth : 0
        border.color: Theme.orange

        Text {
          anchors.centerIn: parent
          text: modelData
          font.family: "Noto Color Emoji"
          font.pointSize: Theme.fontSize + 6
        }
      }

      MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.accept(index)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.words.length > 0 && root.matches.length === 0
      text: "NO EMOJI FOUND"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }
}
