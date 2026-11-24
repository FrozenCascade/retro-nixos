import QtQuick
import qs

// One character of the bar clock. When it changes, the new character fades in over the old one.
Item {
  id: digit

  property string value: "0"
  property real size: Theme.fontSize
  property color color: Theme.fg
  property bool ready: false

  implicitWidth: probe.advanceWidth
  implicitHeight: probe.height
  width: implicitWidth
  height: implicitHeight

  TextMetrics {
    id: probe
    text: "0"
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: digit.size
  }

  Text {
    id: oldText
    anchors.centerIn: parent
    opacity: 0
    color: digit.color
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: digit.size
  }

  Text {
    id: newText
    anchors.centerIn: parent
    color: digit.color
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: digit.size
  }

  ParallelAnimation {
    id: fade
    NumberAnimation { target: newText; property: "opacity"; from: 0.2; to: 1; duration: 280; easing.type: Easing.OutQuad }
    NumberAnimation { target: oldText; property: "opacity"; from: 0.8; to: 0; duration: 280; easing.type: Easing.OutQuad }
  }

  onValueChanged: {
    if (!ready || newText.text === value) {
      newText.text = value;
      return;
    }
    oldText.text = newText.text;
    newText.text = value;
    fade.restart();
  }

  Component.onCompleted: {
    newText.text = value;
    ready = true;
  }
}
