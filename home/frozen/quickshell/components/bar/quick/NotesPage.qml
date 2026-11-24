import QtQuick
import Quickshell
import qs
import qs.components.shared

// QUICK NOTES: the list on the left, the editor on the right (always showing the selected note).
//
// All three pages of the quick window offer the same small interface, so QuickPopup can drive
// whichever one is showing without knowing what is inside:
//   query, active                   set by the window
//   placeholder, hint               texts for the search box and the footer
//   total, canClear, clearWhat      for the "delete all" button and its question
//   move(delta), activate(), togglePin(), copySelected(), removeSelected(), clearAll()
//   reset() (the window opened or the tab was chosen), leave() (the tab is being left)
//   signal done                     "I did what you asked": the window may close (unless pinned)
//   signal focusSearch              "give the keyboard back to the search box"
Item {
  id: page

  // ---- the page interface ----
  property string query: ""
  property bool active: false

  readonly property string placeholder: "search notes"
  readonly property string hint: "↑↓ select   Enter edit   Esc back   Ctrl+N new   Ctrl+P star   Ctrl+D delete"
  readonly property int total: QuickStore.notes.length
  readonly property bool canClear: total > 0
  readonly property string clearWhat: "ALL " + total + " NOTES"

  signal done
  signal focusSearch
  signal keyEvent(var event)           // a key the window may want (Ctrl+N, Ctrl+D ...)

  // ---- state ----
  property bool ready: false           // set once everything below exists
  property string selectedId: ""       // the note shown in the editor
  property string loadedId: ""         // the note whose text is in the editor right now
  property bool loading: false         // true while the editor text is replaced from a note
  property bool fontsOpen: false

  readonly property var note: QuickStore.noteById(selectedId)
  readonly property real noteSize: note && note.size > 0 ? note.size : Theme.fontSize
  readonly property string noteFont: note && note.font ? note.font : Theme.fontSans

  // starred notes first, then the most recently edited
  readonly property var items: {
    const q = page.query.trim().toLowerCase();
    const list = QuickStore.notes.filter(n => q === "" || n.text.toLowerCase().indexOf(q) !== -1);
    return list.slice().sort((a, b) => (Number(b.pinned) - Number(a.pinned)) || (b.updated - a.updated));
  }

  Component.onCompleted: ready = true

  onQueryChanged: {
    if (ready)
      Qt.callLater(() => page.select(0));
  }

  // ---- selection ----
  function indexOfId(id) {
    return page.items.findIndex(n => n.id === id);
  }

  function select(i) {
    if (page.items.length === 0)
      return;
    const k = Math.max(0, Math.min(page.items.length - 1, i));
    list.currentIndex = k;
    page.selectedId = page.items[k].id;
  }

  function move(delta) {
    select(list.currentIndex + delta);
  }

  // a different note was selected: save what was typed, then show the new one
  onSelectedIdChanged: {
    if (!ready)
      return;
    flush();
    loadedId = selectedId;
    const n = QuickStore.noteById(selectedId);
    loading = true;
    edit.text = n ? n.text : "";
    loading = false;
    fontsOpen = false;
  }

  // ---- saving what is typed (a moment after typing stops, and whenever the note changes) ----
  function commitText() {
    if (loadedId !== "")
      QuickStore.updateNote(loadedId, {
        text: edit.text
      });
  }

  function flush() {
    if (saveTimer.running) {
      saveTimer.stop();
      commitText();
    }
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: page.commitText()
  }

  // ---- the page interface: actions ----
  function newNote(text) {
    pruneEmpty();
    const id = QuickStore.newNote(text || "");
    Qt.callLater(() => {
      page.select(page.indexOfId(id));
      edit.forceActiveFocus();
      edit.cursorPosition = edit.text.length;
    });
  }

  // notes that were started and left empty are not worth keeping
  function pruneEmpty() {
    flush();
    const empty = QuickStore.notes.filter(n => n.text.trim() === "" && !n.pinned).map(n => n.id);
    if (empty.length === 0)
      return;
    if (empty.indexOf(selectedId) !== -1)
      selectedId = "";
    QuickStore.removeNotes(empty);
  }

  function activate() {
    if (page.items.length === 0) {
      // nothing matches: start a note from the search text
      newNote(page.query.trim());
      return;
    }
    edit.forceActiveFocus();
    edit.cursorPosition = edit.text.length;
  }

  function togglePin() {
    if (selectedId !== "")
      QuickStore.toggleNotePin(selectedId);
  }

  function copyNote(n) {
    // the note being edited may have newer text than the stored one
    const text = n.id === loadedId ? edit.text : n.text;
    if (text === "")
      return;
    Quickshell.execDetached([Tools.wlCopy, "--", text]);
    page.done();
  }

  function copySelected() {
    if (note)
      copyNote(note);
  }

  function removeNote(n) {
    if (n.id === loadedId)
      flush();
    const current = QuickStore.noteById(n.id);
    if (!current)
      return;

    const at = Math.max(0, indexOfId(n.id));
    if (n.id === selectedId)
      selectedId = "";

    QuickStore.removeNote(current.id);
    QuickUndo.stage("NOTE \"" + QuickStore.brief(QuickStore.noteTitle(current), 26) + "\"", () => {
      QuickStore.restoreNote(current);
      Qt.callLater(() => page.select(page.indexOfId(current.id)));
    }, null);

    // the neighbour takes its place
    Qt.callLater(() => page.select(at));
  }

  function removeSelected() {
    if (note)
      removeNote(note);
  }

  function clearAll() {
    selectedId = "";
    QuickStore.clearNotes();
  }

  // a blank note is always waiting, so the editor is never locked
  function ensureNote() {
    if (QuickStore.notes.length === 0)
      QuickStore.newNote("");
  }

  function reset() {
    pruneEmpty();
    ensureNote();
    fontsOpen = false;
    Qt.callLater(() => page.select(0));
  }

  function leave() {
    pruneEmpty();
  }

  // ---- font and size of the selected note ----
  function setFont(family) {
    if (selectedId !== "")
      QuickStore.updateNote(selectedId, {
        font: family
      });
  }

  function setSize(value) {
    if (selectedId !== "")
      QuickStore.updateNote(selectedId, {
        size: Math.max(7, Math.min(40, Math.round(value)))
      });
  }

  function openFonts() {
    if (!note)
      return;
    fontsOpen = true;
    fontSearch.text = "";
    fontList.currentIndex = 0;
    Qt.callLater(() => fontSearch.forceActiveFocus());
  }

  function closeFonts() {
    fontsOpen = false;
    page.focusSearch();
  }

  // ================= the list =================
  ListView {
    id: list
    x: 0
    y: 0
    width: 220
    height: parent.height
    clip: true
    spacing: 6
    model: page.items
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    // the list changed (a note was added, removed, edited): keep the same note selected
    onModelChanged: {
      if (!page.ready)
        return;
      const i = page.indexOfId(page.selectedId);
      if (i >= 0)
        currentIndex = i;
      else if (page.items.length > 0)
        page.select(0);
    }

    delegate: Item {
      id: row
      required property var modelData
      required property int index

      readonly property bool selected: ListView.isCurrentItem
      readonly property bool showActions: selected || rowMouse.containsMouse || actions.hovered

      width: ListView.view.width - 2
      height: 50

      // raised shadow: present unless selected
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

      Column {
        anchors {
          left: parent.left
          right: parent.right
          verticalCenter: parent.verticalCenter
          leftMargin: 10
          rightMargin: row.showActions ? 92 : 28
        }
        spacing: 1

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: QuickStore.noteTitle(row.modelData)
          color: Theme.fg
          font.family: Theme.fontSans
          font.bold: true
          font.pointSize: (Theme.fontSize + 1) * 0.9
        }

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: QuickStore.notePreview(row.modelData) || Qt.formatDateTime(new Date(row.modelData.updated), "dd MMM  HH:mm")
          color: Qt.lighter(Theme.fgDim, 1.3)
          font.family: Theme.fontSans
          font.pointSize: (Theme.fontSize - 1) * 0.9
        }
      }

      // star marker (the buttons take its place while they show)
      Text {
        anchors {
          right: parent.right
          verticalCenter: parent.verticalCenter
          rightMargin: 10
        }
        visible: row.modelData.pinned === true && !row.showActions
        text: "★"
        color: Theme.yellow
        font.pointSize: Theme.fontSize + 2
      }

      // left click selects, right click stars (like the launcher's pins)
      MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            QuickStore.toggleNotePin(row.modelData.id);
          } else {
            page.select(row.index);
            page.focusSearch();
          }
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
        pinned: row.modelData.pinned === true
        onCopyClicked: page.copyNote(row.modelData)
        onPinClicked: QuickStore.toggleNotePin(row.modelData.id)
        onDeleteClicked: page.removeNote(row.modelData)
      }
    }

    Text {
      anchors.centerIn: parent
      width: parent.width - 20
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      visible: page.items.length === 0
      text: page.query.trim() === "" ? "NO NOTES YET.\nPRESS ENTER TO WRITE ONE." : "NO MATCH.\nPRESS ENTER TO START A NOTE\nFROM THIS TEXT."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }

  // ================= the editor =================
  Item {
    id: editorColumn
    x: 230
    y: 0
    width: parent.width - 230
    height: parent.height

    // font, size
    Item {
      id: toolbar
      width: parent.width
      height: 24

      MiniButton {
        id: fontButton
        width: toolbar.width - sizeRow.width - 10
        text: page.note ? page.noteFont : "-"
        onClicked: page.openFonts()
      }

      Row {
        id: sizeRow
        anchors.right: parent.right
        spacing: 4

        MiniButton {
          text: "A-"
          onClicked: page.setSize(page.noteSize - 1)
        }

        // the size: click it, type a number, press Enter (6 to 96)
        Rectangle {
          width: 38
          height: 22
          radius: Retro.corner
          color: Retro.inset
          border.width: Retro.borderWidth
          border.color: sizeInput.activeFocus ? Theme.yellow : Theme.fgDim

          TextInput {
            id: sizeInput
            anchors {
              fill: parent
              leftMargin: 2
              rightMargin: 2
            }
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            maximumLength: 2
            validator: IntValidator {
              bottom: 1
              top: 96
            }
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1

            property bool edited: false
            property string typed: ""

            // while you are not typing, the box shows the note's size
            Binding {
              target: sizeInput
              property: "text"
              value: String(Math.round(page.noteSize))
              when: !sizeInput.activeFocus
            }

            onTextEdited: {
              edited = true;
              typed = text;
            }

            function commit() {
              if (edited) {
                const v = parseInt(typed);
                if (!isNaN(v))
                  page.setSize(v);
              }
              edited = false;
            }

            onAccepted: {
              commit();
              edit.forceActiveFocus();
            }

            onActiveFocusChanged: {
              if (!activeFocus)
                commit();
            }

            Keys.onEscapePressed: {
              edited = false;
              page.focusSearch();
            }
          }
        }
        MiniButton {
          text: "A+"
          onClicked: page.setSize(page.noteSize + 1)
        }
      }
    }

    Rectangle {
      id: editorBox
      y: 30
      width: parent.width
      height: parent.height - 30
      radius: Retro.corner
      color: Retro.inset

      // yellow while you are typing in it, like the search box
      border.color: edit.activeFocus ? Theme.yellow : Theme.fgDim
      border.width: Retro.borderWidth

      Flickable {
        id: flick
        anchors {
          fill: parent
          margins: 8
        }
        contentWidth: width
        contentHeight: edit.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
          id: edit
          width: flick.width
          height: Math.max(contentHeight, flick.height)
          readOnly: !page.note
          wrapMode: TextEdit.Wrap
          textFormat: TextEdit.PlainText
          selectByMouse: true
          color: Theme.fg
          selectionColor: Theme.aqua
          selectedTextColor: Theme.bg
          font.family: page.noteFont
          font.pointSize: page.noteSize

          onTextChanged: {
            if (!page.loading && page.loadedId !== "")
              saveTimer.restart();
          }

          // scroll so the cursor stays in view
          onCursorRectangleChanged: {
            if (cursorRectangle.y < flick.contentY)
              flick.contentY = cursorRectangle.y;
            else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
              flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
          }

          // Esc gives the keyboard back to the search box (and the arrows to the list)
          Keys.onEscapePressed: page.focusSearch()
        }
      }

      Text {
        anchors {
          left: parent.left
          top: parent.top
          leftMargin: 12
          topMargin: 10
        }
        visible: !!page.note && edit.text === "" && !edit.activeFocus
        text: "write something..."
        color: Theme.fgDim
        font.family: page.noteFont
        font.pointSize: page.noteSize
      }

      Text {
        anchors.centerIn: parent
        visible: !page.note
        text: "NO NOTE SELECTED"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }
  }

  // ================= the font picker (covers the editor while it is open) =================
  Rectangle {
    id: fontPicker
    visible: page.fontsOpen
    z: 20
    x: editorColumn.x
    y: 0
    width: editorColumn.width
    height: page.height
    radius: Retro.corner
    color: Theme.bg
    border.width: Retro.borderWidth
    border.color: Theme.fg

    // "" is the default font, then every installed family that matches the filter
    readonly property var rows: {
      const q = fontSearch.text.trim().toLowerCase();
      const all = (typeof Qt.fontFamilies === "function") ? Qt.fontFamilies() : [Theme.fontMono, Theme.fontSans];
      return [""].concat(all.filter(f => q === "" || f.toLowerCase().indexOf(q) !== -1));
    }

    function pick(family) {
      page.setFont(family);
      page.closeFonts();
    }

    // click on empty space: do nothing (and do not reach the editor)
    MouseArea {
      anchors.fill: parent
    }

    Rectangle {
      id: fontSearchBox
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        margins: 8
      }
      height: 30
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: Theme.yellow

      TextInput {
        id: fontSearch
        anchors {
          fill: parent
          leftMargin: 10
          rightMargin: 10
        }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        selectByMouse: true
        clip: true
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize

        onTextChanged: fontList.currentIndex = 0
        onAccepted: fontPicker.pick(fontPicker.rows[fontList.currentIndex])

        Keys.onUpPressed: fontList.decrementCurrentIndex()
        Keys.onDownPressed: fontList.incrementCurrentIndex()
        Keys.onEscapePressed: page.closeFonts()
      }

      Text {
        anchors {
          left: parent.left
          verticalCenter: parent.verticalCenter
          leftMargin: 10
        }
        visible: fontSearch.text === ""
        text: "filter fonts  |  Enter picks"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize
      }
    }

    ListView {
      id: fontList
      anchors {
        left: parent.left
        right: parent.right
        top: fontSearchBox.bottom
        bottom: parent.bottom
        margins: 8
      }
      clip: true
      spacing: 2
      model: fontPicker.rows
      currentIndex: 0
      boundsBehavior: Flickable.StopAtBounds
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

      delegate: Rectangle {
        id: fontRow
        required property var modelData
        required property int index

        width: ListView.view.width
        height: 28
        radius: Retro.corner
        color: ListView.isCurrentItem ? Theme.bgSel : "transparent"

        Text {
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10
            rightMargin: 10
          }
          elide: Text.ElideRight
          text: fontRow.modelData === "" ? "DEFAULT  (" + Theme.fontSans + ")" : fontRow.modelData
          color: ListView.isCurrentItem ? Theme.orange : Theme.fg
          font.family: fontRow.modelData === "" ? Theme.fontSans : fontRow.modelData
          font.pointSize: Theme.fontSize
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPositionChanged: fontList.currentIndex = fontRow.index
          onClicked: fontPicker.pick(fontRow.modelData)
        }
      }
    }
  }
}
