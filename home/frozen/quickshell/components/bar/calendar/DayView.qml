import QtQuick
import qs
import "../../../lib/calendar.js" as Cal

// One day by the hour: reminders as blocks that last as long as they do, events and moon/season
// moments at their exact minute, all-day things as chips on top. Ctrl+wheel zooms the hours.
// Click a reminder or event to edit it.
Item {
  id: root

  property int dn: 0
  property real hourH: 48

  signal edit(string kind, string id)

  readonly property var rows: CalendarStore.agenda(dn)
  readonly property var band: rows.filter(r => r.startMin === undefined)
  readonly property var timed: layout(rows.filter(r => r.startMin !== undefined))
  readonly property bool isToday: dn === Clock.todayDn
  readonly property real nowMin: Clock.zd.getUTCHours() * 60 + Clock.zd.getUTCMinutes()
  readonly property real gutter: 50

  // side-by-side lanes for things that overlap in time
  function layout(list) {
    const items = list.map(r => ({ row: r, a: r.startMin, b: Math.max(r.endMin, r.startMin + 28), lane: 0, lanes: 1 }));
    items.sort((x, y) => x.a - y.a);
    let cluster = [];
    let laneEnds = [];
    let clusterEnd = -1;
    const flush = () => {
      for (const it of cluster)
        it.lanes = laneEnds.length;
      cluster = [];
      laneEnds = [];
    };
    for (const it of items) {
      if (cluster.length > 0 && it.a >= clusterEnd) {
        flush();
        clusterEnd = -1;
      }
      let lane = laneEnds.findIndex(e => e <= it.a);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.push(0);
      }
      laneEnds[lane] = it.b;
      it.lane = lane;
      cluster.push(it);
      clusterEnd = Math.max(clusterEnd, it.b);
    }
    flush();
    return items;
  }

  // scroll to now (today), else the first thing of the day, else the morning
  function reveal() {
    let m = 8 * 60;
    if (isToday)
      m = nowMin;
    else if (timed.length > 0)
      m = timed[0].a;
    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, m * hourH / 60 - 80));
  }

  onDnChanged: Qt.callLater(reveal)
  onVisibleChanged: {
    if (visible)
      Qt.callLater(reveal);
  }

  Flow {
    id: chips
    width: parent.width
    spacing: 6
    visible: root.band.length > 0

    Repeater {
      model: root.band
      delegate: Rectangle {
        required property var modelData
        readonly property color tint: ({ holiday: Theme.green, event: Theme.blue, reminder: Theme.orange, season: Theme.yellow, moon: Theme.fgDim })[modelData.kind] || Theme.fgDim
        width: Math.min(label.implicitWidth + 20, chips.width)
        height: 22
        radius: Retro.corner
        color: Retro.inset
        border.width: Retro.borderWidth
        border.color: tint

        Text {
          id: label
          anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          text: modelData.title + (modelData.kind === "moon" ? "  " + modelData.detail : "")
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        MouseArea {
          anchors.fill: parent
          enabled: modelData.id !== undefined
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.edit(modelData.kind, modelData.id)
        }
      }
    }
  }

  Flickable {
    id: flick
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: chips.visible ? chips.bottom : parent.top; topMargin: chips.visible ? 8 : 0 }
    clip: true
    contentWidth: width
    contentHeight: 24 * root.hourH
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Repeater {
      model: 25
      delegate: Item {
        required property int index
        y: index * root.hourH
        width: flick.width
        height: 1

        Text {
          visible: index < 24
          x: 0
          y: 2
          width: root.gutter - 8
          horizontalAlignment: Text.AlignRight
          text: (index < 10 ? "0" : "") + index + ":00"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        Rectangle {
          x: root.gutter
          width: parent.width - root.gutter
          height: 1
          color: Theme.fgDim
        }

        Rectangle {
          visible: index < 24 && root.hourH >= 60
          x: root.gutter
          y: root.hourH / 2
          width: parent.width - root.gutter
          height: 1
          color: Theme.fgDim
          opacity: 0.35
        }
      }
    }

    Repeater {
      model: root.timed
      delegate: Rectangle {
        id: block
        required property var modelData
        readonly property color tint: ({ holiday: Theme.green, event: Theme.blue, reminder: Theme.orange, season: Theme.yellow, phase: Theme.yellow })[modelData.row.kind] || Theme.fgDim
        readonly property real avail: flick.width - root.gutter - 8

        x: root.gutter + 4 + avail * modelData.lane / modelData.lanes
        width: avail / modelData.lanes - 3
        y: modelData.row.startMin * root.hourH / 60
        height: Math.max(20, (modelData.row.endMin - modelData.row.startMin) * root.hourH / 60)
        radius: Retro.corner
        color: Retro.inset
        border.width: Retro.borderWidth
        border.color: tint

        Text {
          anchors { fill: parent; leftMargin: 6; rightMargin: 6; topMargin: 2 }
          elide: Text.ElideRight
          wrapMode: Text.Wrap
          maximumLineCount: Math.max(1, Math.floor(block.height / 16))
          text: modelData.row.detail + "  " + modelData.row.title
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        MouseArea {
          anchors.fill: parent
          enabled: modelData.row.id !== undefined
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.edit(modelData.row.kind, modelData.row.id)
        }
      }
    }

    // now
    Rectangle {
      visible: root.isToday
      x: root.gutter
      y: root.nowMin * root.hourH / 60 - 1
      width: flick.width - root.gutter
      height: 2
      color: Theme.red
    }
  }

  // Ctrl+wheel zooms; the plain wheel scrolls the day
  MouseArea {
    anchors.fill: flick
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
      if (wheel.modifiers & Qt.ControlModifier) {
        wheel.accepted = true;
        root.hourH = Math.max(28, Math.min(140, root.hourH * (wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15)));
      } else {
        wheel.accepted = false;
      }
    }
  }
}
