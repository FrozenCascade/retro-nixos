import QtQuick
import qs

// The color key on the weather map: a title, then a bar of colors with labels beside it.
//   stops  the colors from the top of the bar (p = 0) to the bottom (p = 1), in that order
//   ticks  the labels, each at its own p
Rectangle {
  id: legend

  property string title: ""
  property var stops: []                  // [{ p: 0..1, c: "#rrggbb" }]
  property var ticks: []                  // [{ p: 0..1, text: "20°C" }]
  property real barHeight: 170            // edit here
  property real barWidth: 10
  property real labelWidth: 44

  readonly property int slices: 48
  readonly property real pad: 6
  readonly property real head: title !== "" ? 16 : 0

  width: Math.max(pad * 3 + labelWidth + barWidth, titleText.implicitWidth + pad * 2)
  height: head + barHeight + pad * 2
  radius: 3
  color: Qt.rgba(0, 0, 0, 0.55)

  // the color at p, blended between the two stops around it
  function colorAt(p) {
    const s = stops;

    if (s.length === 0)
      return "transparent";
    if (p <= s[0].p)
      return s[0].c;
    for (let i = 1; i < s.length; i++) {
      if (p <= s[i].p) {
        const k = (p - s[i - 1].p) / (s[i].p - s[i - 1].p);
        const a = Qt.color(s[i - 1].c);
        const b = Qt.color(s[i].c);
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
      }
    }
    return s[s.length - 1].c;
  }

  Text {
    id: titleText
    x: legend.pad
    y: legend.pad - 1
    text: legend.title
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 3
  }

  Repeater {
    model: legend.slices

    Rectangle {
      required property int index

      x: legend.width - legend.pad - legend.barWidth
      y: legend.pad + legend.head + index * legend.barHeight / legend.slices
      width: legend.barWidth
      height: legend.barHeight / legend.slices + 0.5
      color: legend.colorAt((index + 0.5) / legend.slices)
    }
  }

  Repeater {
    model: legend.ticks

    Text {
      required property var modelData

      x: legend.width - legend.pad * 2 - legend.barWidth - legend.labelWidth
      y: legend.pad + legend.head + modelData.p * legend.barHeight - height / 2
      width: legend.labelWidth
      horizontalAlignment: Text.AlignRight
      text: modelData.text
      color: Theme.fg
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 3
    }
  }
}
