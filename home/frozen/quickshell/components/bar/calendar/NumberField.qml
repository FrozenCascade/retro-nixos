import QtQuick
import qs
import qs.components.shared

// [-] 07 [+]  with an optional big step on each side. It only reports edits; the owner sets `value`.
Row {
  id: field

  property int value: 0
  property int from: 0
  property int to: 59
  property int step: 1
  property int bigStep: 0
  property bool wrap: false

  signal edited(int v)

  spacing: 4

  function pad(n) {
    return (n < 10 ? "0" : "") + n;
  }

  function move(d) {
    let v = field.value + d;
    if (field.wrap) {
      const n = field.to - field.from + 1;
      v = ((v - field.from) % n + n) % n + field.from;
    } else {
      v = Math.max(field.from, Math.min(field.to, v));
    }
    field.edited(v);
  }

  onValueChanged: input.text = pad(value)
  Component.onCompleted: input.text = pad(value)

  MiniButton { visible: field.bigStep > 0; text: "-" + field.bigStep; onClicked: field.move(-field.bigStep) }
  MiniButton { text: "-"; onClicked: field.move(-field.step) }

  Rectangle {
    width: 40
    height: 22
    radius: Retro.corner
    color: Retro.inset
    border.width: Retro.borderWidth
    border.color: input.activeFocus ? Theme.yellow : Theme.fgDim

    TextInput {
      id: input
      anchors.fill: parent
      horizontalAlignment: TextInput.AlignHCenter
      verticalAlignment: TextInput.AlignVCenter
      color: Theme.fg
      selectByMouse: true
      inputMethodHints: Qt.ImhDigitsOnly
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
      onEditingFinished: {
        const n = parseInt(text);
        if (!isNaN(n))
          field.edited(Math.max(field.from, Math.min(field.to, n)));
        text = field.pad(field.value);
      }
    }
  }

  MiniButton { text: "+"; onClicked: field.move(field.step) }
  MiniButton { visible: field.bigStep > 0; text: "+" + field.bigStep; onClicked: field.move(field.bigStep) }
}
