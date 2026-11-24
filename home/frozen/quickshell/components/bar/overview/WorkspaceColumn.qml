import Quickshell
import QtQuick
import qs
import qs.components.shared

// One workspace in the overview: its name, the windows on it, and below them the minimized ones.
// Windows are dragged between the two areas and between workspaces; the overview does the dropping.
Rectangle {
  id: col

  property string wsKey: ""
  property var windows: []                 // every window the overview knows about
  property var matchSet: null              // the search matches by address, or null = everything matches
  property string selectedAddress: ""
  property string previewAddress: ""       // the window whose picture is showing
  property bool current: false             // the workspace this monitor is showing
  property string dropZone: ""             // while a window is dragged over this column: "open" or "hidden"
  property int dropIndex: -1               // and the row it would go in front of there (the row count = last)

  // below this height (inside the column) is the minimized area
  readonly property real hiddenTop: 204

  signal switchRequested                   // the header was clicked
  signal windowChosen                      // a window was clicked
  signal previewToggled(var toplevel)
  signal dragStarted(var toplevel, var point)
  signal dragMoved(var point)
  signal dragFinished(var point)
  signal dragCancelled

  readonly property var openWindows: windows.filter(t => Desktop.homeKey(t) === wsKey && !Desktop.isHidden(t))
  readonly property var hiddenWindows: windows.filter(t => Desktop.homeKey(t) === wsKey && Desktop.isHidden(t))

  // the windows of one area ("open" or "hidden"), in the order shown
  function windowsOf(zone) {
    return zone === "open" ? openWindows : hiddenWindows;
  }

  // where a point (in this column's coordinates) lands in an area's list: the index of the row a window
  // dropped there would go in front of (the row count = at the end)
  function insertIndexAt(zone, p) {
    const list = zone === "open" ? openList : hiddenList;
    const count = windowsOf(zone).length;
    if (count === 0)
      return 0;
    const q = list.mapFromItem(col, p.x, p.y);
    if (q.y < 0)
      return 0;
    const x = Math.max(1, Math.min(list.width - 1, q.x));
    const i = list.indexAt(x + list.contentX, q.y + list.contentY);
    if (i < 0)
      return count;
    const item = list.itemAtIndex(i);
    const lower = item && (q.y + list.contentY - item.y) > item.height / 2;
    return lower ? i + 1 : i;
  }

  // y (in this column's coordinates) of the line that shows where a dragged window would go
  function dropLineY(zone, index) {
    const list = zone === "open" ? openList : hiddenList;
    const count = windowsOf(zone).length;
    if (count === 0)
      return list.y + 2;
    const last = index >= count;
    const item = list.itemAtIndex(last ? count - 1 : index);
    if (!item)
      return list.y + 2;
    return list.y + item.y - list.contentY + (last ? item.height + 1 : -3);
  }

  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: current ? Theme.orange : Theme.fgDim

  // ---- header: click to go to this workspace ----
  Item {
    x: 2
    y: 2
    width: parent.width - 4
    height: 32

    Rectangle {
      anchors.fill: parent
      radius: Retro.corner
      color: headMouse.containsMouse ? Theme.bgSel : "transparent"
    }

    Text {
      id: glyphText
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        leftMargin: 8
      }
      text: Desktop.glyph(col.wsKey)
      color: col.current ? Theme.orange : Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize + 5
    }

    Text {
      anchors {
        left: glyphText.right
        verticalCenter: parent.verticalCenter
        leftMargin: 8
      }
      text: Desktop.shortName(col.wsKey)
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    // how many windows
    Text {
      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
        rightMargin: 8
      }
      text: col.openWindows.length + col.hiddenWindows.length
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    MouseArea {
      id: headMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: col.switchRequested()
    }
  }

  // ---- the windows on this workspace ----
  ListView {
    id: openList
    x: 6
    y: 38
    width: parent.width - 12
    height: 164
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    model: ScriptModel {
      values: col.openWindows
    }

    delegate: WindowRow {
      required property var modelData
      toplevel: modelData
      width: ListView.view.width
      onlyClose: true
      selected: modelData.address === col.selectedAddress
      previewing: modelData.address === col.previewAddress
      dimmed: col.matchSet !== null && !col.matchSet[modelData.address]
      onChosen: col.windowChosen()
      onPreviewToggled: col.previewToggled(modelData)
      onDragStarted: point => col.dragStarted(modelData, point)
      onDragMoved: point => col.dragMoved(point)
      onDragFinished: point => col.dragFinished(point)
      onDragCancelled: col.dragCancelled()
    }

    Text {
      anchors.centerIn: parent
      visible: col.openWindows.length === 0
      text: "EMPTY"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }

  // ---- the minimized windows, below ----
  Rectangle {
    x: 6
    y: 206
    width: parent.width - 12
    height: 2
    color: Theme.fgDim
  }

  Text {
    x: 8
    y: 210
    text: "MINIMIZED"
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }

  ListView {
    id: hiddenList
    x: 6
    y: 226
    width: parent.width - 12
    height: 92
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    model: ScriptModel {
      values: col.hiddenWindows
    }

    delegate: WindowRow {
      required property var modelData
      toplevel: modelData
      width: ListView.view.width
      onlyClose: true
      selected: modelData.address === col.selectedAddress
      previewing: modelData.address === col.previewAddress
      dimmed: col.matchSet !== null && !col.matchSet[modelData.address]
      onChosen: col.windowChosen()
      onPreviewToggled: col.previewToggled(modelData)
      onDragStarted: point => col.dragStarted(modelData, point)
      onDragMoved: point => col.dragMoved(point)
      onDragFinished: point => col.dragFinished(point)
      onDragCancelled: col.dragCancelled()
    }
  }

  // ---- while a window is dragged over this column: where it would go in the list ----
  Rectangle {
    x: 6
    y: col.dropLineY(col.dropZone, col.dropIndex)
    width: parent.width - 12
    height: 3
    z: 6
    radius: 1
    color: Theme.orange
    visible: col.dropZone !== "" && col.dropIndex >= 0
  }

  // ---- and the area it would land in lights up ----
  Rectangle {
    x: 3
    y: 36
    width: parent.width - 6
    height: col.hiddenTop - 36
    radius: Retro.corner
    visible: col.dropZone === "open"
    color: Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.15)
    border.width: Retro.borderWidth
    border.color: Theme.orange
  }

  Rectangle {
    x: 3
    y: col.hiddenTop
    width: parent.width - 6
    height: parent.height - col.hiddenTop - 3
    radius: Retro.corner
    visible: col.dropZone === "hidden"
    color: Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.15)
    border.width: Retro.borderWidth
    border.color: Theme.orange
  }
}
