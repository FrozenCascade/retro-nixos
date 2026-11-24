import QtQuick
import qs

// A retro LCD-style line graph: dark inset box, faint grid, filled line, axis labels.
Item {
  id: graph

  property var values: []              // newest last
  property int historyLength: 20
  property real maxValue: 100
  property color lineColor: Theme.orange
  property string topLabel: "100%"     // value at the top of the box
  property string bottomLabel: "0"     // value at the bottom of the box
  property string leftTimeLabel: "-" + historyLength + "s"
  property string rightTimeLabel: "NOW"

  implicitHeight: 118                  // the box (100) plus the time labels

  onValuesChanged: canvas.requestPaint()

  Rectangle {
    id: box
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
    height: 100
    radius: 3
    color: Qt.rgba(0, 0, 0, 0.35)
    border.color: Theme.fgDim
    border.width: Retro.borderWidth

    Canvas {
      id: canvas
      anchors.fill: parent
      anchors.margins: 2

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const w = width;
        const h = height;

        // faint grid
        ctx.strokeStyle = Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10);
        ctx.lineWidth = 1;

        for (let i = 1; i < 4; i++) {
          const y = Math.round(h * i / 4) + 0.5;
          ctx.beginPath();
          ctx.moveTo(0, y);
          ctx.lineTo(w, y);
          ctx.stroke();
        }

        const v = graph.values;
        if (!v || v.length < 2)
          return;

        // newest sample on the right edge, older ones to its left
        const step = w / (graph.historyLength - 1);
        const xs = v.map((_, i) => w - (v.length - 1 - i) * step);
        const ys = v.map(x => h - 1 - Math.max(0, Math.min(1, x / graph.maxValue)) * (h - 3));

        // fill under the line
        ctx.beginPath();
        ctx.moveTo(xs[0], h);

        for (let i = 0; i < v.length; i++)
          ctx.lineTo(xs[i], ys[i]);

        ctx.lineTo(xs[v.length - 1], h);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(graph.lineColor.r, graph.lineColor.g, graph.lineColor.b, 0.22);
        ctx.fill();

        // the line
        ctx.beginPath();
        ctx.moveTo(xs[0], ys[0]);

        for (let i = 1; i < v.length; i++)
          ctx.lineTo(xs[i], ys[i]);

        ctx.strokeStyle = graph.lineColor;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.stroke();
      }
    }

    // value axis labels (units)
    Text {
      anchors {
        left: parent.left
        top: parent.top
        leftMargin: 6
        topMargin: 4
      }
      text: graph.topLabel
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 3
    }

    Text {
      anchors {
        left: parent.left
        bottom: parent.bottom
        leftMargin: 6
        bottomMargin: 4
      }
      text: graph.bottomLabel
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 3
    }
  }

  // time axis labels
  Text {
    anchors {
      left: parent.left
      top: box.bottom
      topMargin: 3
    }
    text: graph.leftTimeLabel
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 3
  }

  Text {
    anchors {
      right: parent.right
      top: box.bottom
      topMargin: 3
    }
    text: graph.rightTimeLabel
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.pointSize: Theme.fontSize - 3
  }
}
