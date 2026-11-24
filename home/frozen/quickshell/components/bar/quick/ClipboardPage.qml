import QtQuick
import Quickshell
import qs
import qs.components.shared

// CLIPBOARD: starred entries first, then the history from cliphist.
// Offers the same page interface as NotesPage (see the comment there).
Item {
  id: page

  // ---- the page interface ----
  property string query: ""
  property bool active: false

  readonly property string placeholder: "search clipboard history"
  readonly property string hint: "↑↓ select   Enter copy   Ctrl+P star   Ctrl+D delete   Tab next page"
  readonly property int total: ClipHistory.shown.length
  readonly property bool canClear: total > 0
  readonly property string clearWhat: "THE CLIPBOARD HISTORY (" + total + " ENTRIES, STARRED ONES STAY)"

  signal done
  signal focusSearch

  // ---- state ----
  property bool ready: false
  property int selected: 0            // the row we want highlighted

  // one flat list: { kind: "snippet" | "clip", id, text, isImage, ref }
  readonly property var items: {
    const q = page.query.trim().toLowerCase();
    const out = [];

    for (const s of QuickStore.snippets) {
      if (q === "" || s.text.toLowerCase().indexOf(q) !== -1)
        out.push({
          kind: "snippet",
          id: s.id,
          text: s.text,
          isImage: false,
          ref: s
        });
    }

    for (const e of ClipHistory.shown) {
      if (q === "" || e.preview.toLowerCase().indexOf(q) !== -1)
        out.push({
          kind: "clip",
          id: e.id,
          text: e.preview,
          isImage: e.isImage,
          ref: e
        });
    }

    return out;
  }

  Component.onCompleted: ready = true

  onQueryChanged: {
    if (ready)
      Qt.callLater(() => page.select(0));
  }

  function select(i) {
    selected = Math.max(0, Math.min(page.items.length - 1, i));
    list.currentIndex = selected;
  }

  function move(delta) {
    select(selected + delta);
  }

  function current() {
    return page.items[list.currentIndex];
  }

  // ---- the page interface: actions ----
  function copyItem(it) {
    if (!it)
      return;
    if (it.kind === "snippet")
      Quickshell.execDetached([Tools.wlCopy, "--", it.text]);
    else
      ClipHistory.copy(it.ref);
    page.done();
  }

  function activate() {
    copyItem(current());
  }

  function copySelected() {
    copyItem(current());
  }

  // star: keep an entry for good. On a starred entry it takes the star away (with undo).
  function togglePinOf(it) {
    if (!it)
      return;
    if (it.kind === "snippet")
      removeItem(it);
    else
      ClipHistory.pin(it.ref);
  }

  function togglePin() {
    togglePinOf(current());
  }

  function removeItem(it) {
    if (!it)
      return;
    if (it.kind === "snippet") {
      const s = it.ref;
      QuickStore.removeSnippet(s.id);
      QuickUndo.stage("STARRED \"" + QuickStore.brief(s.text, 26) + "\"", () => QuickStore.restoreSnippet(s), null);
    } else {
      ClipHistory.remove(it.ref);
    }
    Qt.callLater(() => page.select(page.selected));
  }

  function removeSelected() {
    removeItem(current());
  }

  function clearAll() {
    ClipHistory.wipe();
  }

  function reset() {
    ClipHistory.refresh();
    Qt.callLater(() => page.select(0));
  }

  function leave() {
  }

  // ================= the list =================
  ListView {
    id: list
    anchors.fill: parent
    clip: true
    spacing: 6
    model: page.items
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    // the list changed (a new copy arrived, something was deleted): keep the same row highlighted
    onModelChanged: {
      if (page.ready)
        currentIndex = Math.max(0, Math.min(page.selected, page.items.length - 1));
    }

    delegate: Item {
      id: row
      required property var modelData
      required property int index

      readonly property bool selected: ListView.isCurrentItem
      readonly property bool showActions: selected || rowMouse.containsMouse || actions.hovered

      width: ListView.view.width - 2
      height: 40

      Rectangle {
        x: 2
        y: 2
        width: parent.width
        height: parent.height
        radius: Retro.corner
        color: Retro.shadowColor
        visible: !row.selected
      }

      Rectangle {
        anchors.fill: parent
        radius: Retro.corner
        color: row.selected ? Theme.bgSel : Theme.bgAlt
      }

      // star for saved entries, IMG for pictures
      Text {
        id: badge
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
          leftMargin: 10
        }
        width: 24
        text: row.modelData.kind === "snippet" ? "★" : (row.modelData.isImage ? "IMG" : "")
        color: row.modelData.kind === "snippet" ? Theme.yellow : Theme.aqua
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: row.modelData.kind === "snippet" ? Theme.fontSize + 1 : Theme.fontSize - 2
      }

      Text {
        anchors {
          left: badge.right
          right: parent.right
          verticalCenter: parent.verticalCenter
          leftMargin: 6
          rightMargin: row.showActions ? 92 : 12
        }
        elide: Text.ElideRight
        text: row.modelData.isImage ? row.modelData.text.replace(/^\[\[ binary data (.*) \]\]$/, "$1") : row.modelData.text.replace(/\s+/g, " ")
        color: Theme.fg
        font.family: Theme.fontSans
        font.pointSize: (Theme.fontSize + 1) * 0.9
      }

      // left click copies, right click stars (like the launcher's pins)
      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: page.select(row.index)
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton)
            page.togglePinOf(row.modelData);
          else
            page.copyItem(row.modelData);
        }
      }

      RowActions {
        id: actions
        visible: row.showActions
        anchors {
          right: parent.right
          verticalCenter: parent.verticalCenter
          rightMargin: 6
        }
        showPin: !row.modelData.isImage
        pinned: row.modelData.kind === "snippet"
        onCopyClicked: page.copyItem(row.modelData)
        onPinClicked: page.togglePinOf(row.modelData)
        onDeleteClicked: page.removeItem(row.modelData)
      }
    }

    Text {
      anchors.centerIn: parent
      width: parent.width - 20
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      visible: page.items.length === 0
      text: page.query.trim() === "" ? "NOTHING COPIED YET.\n(THE HISTORY FILLS UP AS YOU COPY.)" : "NO MATCH"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }
}
