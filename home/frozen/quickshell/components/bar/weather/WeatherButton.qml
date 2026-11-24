import QtQuick
import qs
import qs.components.shared

// The weather button in the top bar: [icon] 61°F
Item {
  id: button

  property bool open: false
  signal clicked
  signal middleClicked

  readonly property real padX: 9

  // reserves room for three digits plus °F so the button never changes width
  TextMetrics {
    id: tempMetrics
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
    text: "000°F"
  }

  width: padX * 2 + 20 + 6 + tempMetrics.advanceWidth
  height: 22

  KeyFace {
    anchors.fill: parent
    down: button.open
  }

  Row {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    spacing: 6

    // weather icon (fixed width so different glyphs don't shift the layout)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      horizontalAlignment: Text.AlignHCenter
      text: Weather.hidden ? "\uf070" : Weather.glyph          // an eye with a line through it while hidden
      color: Weather.hidden ? Theme.fgDim : Theme.fg
      font.family: Weather.hidden ? Theme.fontMono : "Weather Icons"
      font.pointSize: Theme.fontSize + 1
    }

    // temperature, right-aligned in a fixed-width field
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: tempMetrics.advanceWidth
      horizontalAlignment: Text.AlignRight
      text: Weather.hidden ? "---" : Weather.tempText
      color: Weather.hidden ? Theme.fgDim : Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton)
        button.middleClicked();
      else
        button.clicked();
    }
  }
}
