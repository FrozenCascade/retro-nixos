import QtQuick
import Quickshell
import qs
import qs.components.shared

// KEYBOARD LAYOUTS: the layouts from settings.nix, the active one marked, starred ones on top.
// Offers the same page interface as NotesPage (see the comment there).
Item {
  id: page

  // ---- the page interface ----
  property string query: ""
  property bool active: false

  readonly property string placeholder: "filter layouts"
  readonly property string hint: "↑↓ select   Enter switch   Ctrl+P star   Tab next page"
  readonly property int total: items.length
  readonly property bool canClear: false
  readonly property string clearWhat: ""

  signal done
  signal focusSearch

  // ---- state ----
  property bool ready: false
  property int selected: 0

  // { index, short, name, pinned }, starred first, then in the order Hyprland cycles them
  readonly property var items: {
    const q = page.query.trim().toLowerCase();
    return Settings.keyboardLayouts.map((l, i) => ({
          index: i,
          short: l.short,
          name: l.name,
          pinned: QuickStore.isLayoutPinned(l.short)
        })).filter(l => q === "" || l.name.toLowerCase().indexOf(q) !== -1 || l.short.toLowerCase().indexOf(q) !== -1).sort((a, b) => (Number(b.pinned) - Number(a.pinned)) || (a.index - b.index));
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
  function switchTo(it) {
    if (!it)
      return;
    KeyboardState.switchTo(it.index);
    page.done();
  }

  function activate() {
    switchTo(current());
  }

  function togglePinOf(it) {
    if (it)
      QuickStore.toggleLayoutPin(it.short);
  }

  function togglePin() {
    togglePinOf(current());
  }

  // nothing to copy or delete here
  function copySelected() {
  }

  function removeSelected() {
  }

  function clearAll() {
  }

  function reset() {
    Qt.callLater(() => page.select(0));
  }

  function leave() {
  }

  // ================= the current layout, always shown =================
  Rectangle {
    id: banner
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      rightMargin: 2
    }
    height: 56
    radius: Retro.corner
    color: Retro.inset
    border.width: Retro.borderWidth
    border.color: Theme.fgDim

    Text {
      id: bigShort
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        leftMargin: 16
      }
      text: KeyboardState.activeShort
      color: Theme.orange
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize + 10
    }

    Column {
      anchors {
        left: bigShort.right
        right: parent.right
        verticalCenter: parent.verticalCenter
        leftMargin: 16
        rightMargin: 12
      }
      spacing: 2

      Text {
        text: "CURRENT LAYOUT"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: KeyboardState.activeName !== "" ? KeyboardState.activeName : "unknown"
        color: Theme.fg
        font.family: Theme.fontSans
        font.bold: true
        font.pointSize: Theme.fontSize
      }
    }
  }

  // ================= the list =================
  ListView {
    id: list
    anchors {
      left: parent.left
      right: parent.right
      top: banner.bottom
      bottom: parent.bottom
      topMargin: 10
    }
    clip: true
    spacing: 6
    model: page.items
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    onModelChanged: {
      if (page.ready)
        currentIndex = Math.max(0, Math.min(page.selected, page.items.length - 1));
    }

    delegate: Item {
      id: row
      required property var modelData
      required property int index

      readonly property bool selected: ListView.isCurrentItem
      readonly property bool isActive: modelData.index === KeyboardState.activeIndex
      readonly property bool showActions: selected || rowMouse.containsMouse || actions.hovered

      width: ListView.view.width - 2
      height: 44

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

        // the layout in use gets an orange outline
        border.width: row.isActive ? Retro.borderWidth : 0
        border.color: Theme.orange
      }

      Text {
        id: shortName
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
          leftMargin: 12
        }
        width: 44
        text: row.modelData.short
        color: row.isActive ? Theme.orange : Theme.aqua
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 1
      }

      Column {
        anchors {
          left: shortName.right
          right: parent.right
          verticalCenter: parent.verticalCenter
          leftMargin: 8
          rightMargin: row.showActions ? 40 : 12
        }
        spacing: 1

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: row.modelData.name
          color: Theme.fg
          font.family: Theme.fontSans
          font.bold: true
          font.pointSize: (Theme.fontSize + 1) * 0.9
        }

        Text {
          visible: row.isActive
          text: "IN USE"
          color: Theme.orange
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }
      }

      Text {
        anchors {
          right: parent.right
          verticalCenter: parent.verticalCenter
          rightMargin: 12
        }
        visible: row.modelData.pinned && !row.showActions
        text: "★"
        color: Theme.yellow
        font.pointSize: Theme.fontSize + 2
      }

      // left click switches, right click stars (like the launcher's pins)
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
            page.switchTo(row.modelData);
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
        showCopy: false
        showDelete: false
        pinned: row.modelData.pinned
        onPinClicked: page.togglePinOf(row.modelData)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: page.items.length === 0
      text: "NO LAYOUT MATCHES"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }
}
