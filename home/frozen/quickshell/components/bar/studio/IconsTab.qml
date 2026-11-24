import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.components.shared

// Studio tab: search the icon pack by name. Click an icon (or press Enter in the search box) to copy its name, which is
// what launcher entries, .desktop files and QS_ICON_THEME lookups use. COPY PATH copies the file itself.
// The list is read once, the first time the tab opens.
Item {
  id: win

  property var all: []              // every icon, { name, path }, sorted by name
  property var shown: []            // what matches the search
  property int picked: -1           // index into `shown`
  property string note: ""          // "COPIED ..." for a moment

  readonly property int maxShown: 1500
  readonly property var current: picked >= 0 && picked < shown.length ? shown[picked] : null

  function filter() {
    const words = search.text.toLowerCase().split(/\s+/).filter(w => w !== "");
    const out = [];
    for (const icon of all) {
      if (words.every(w => icon.name.indexOf(w) !== -1)) {
        out.push(icon);
        if (out.length >= maxShown)
          break;
      }
    }
    shown = out;
    picked = out.length > 0 ? 0 : -1;
  }

  // when one name exists in several places: never a symbolic file, then svg, then the apps folder, then the
  // largest size (the pack's 16px files are flat glyphs; the scalable folder holds the colored artwork)
  function rank(path) {
    if (path.indexOf("/symbolic/") !== -1)
      return 0;
    const size = /\/(\d+)(@2x)?\//.exec(path);
    const px = path.indexOf("/scalable") !== -1 ? 512 : (size ? Number(size[1]) : 0);
    return (path.endsWith(".svg") ? 10000 : 0) + (path.indexOf("/apps/") !== -1 ? 1000 : 0) + px + 1;
  }

  function parse(text) {
    const best = {};
    for (const line of text.split("\n")) {
      const tab = line.indexOf("\t");
      if (tab < 0)
        continue;
      const file = line.slice(0, tab);
      const path = line.slice(tab + 1);
      const name = file.replace(/\.(svg|png)$/, "");
      if (!(name in best) || rank(path) > rank(best[name]))
        best[name] = path;
    }
    all = Object.keys(best).sort().map(n => ({ name: n, path: best[n] }));
    filter();
  }

  function copy(text, label) {
    Quickshell.execDetached(["wl-copy", text]);
    note = "COPIED " + label;
    noteTimer.restart();
  }

  // read the pack the first time the tab is shown
  onVisibleChanged: {
    if (!visible)
      return;
    if (all.length === 0 && !scan.running)
      scan.running = true;
    search.forceActiveFocus();
  }

  Process {
    id: scan
    command: ["find", "-L", Tools.iconTheme, "-type", "f", "(", "-name", "*.svg", "-o", "-name", "*.png", ")", "-printf", "%f\t%p\n"]
    stdout: StdioCollector {
      onStreamFinished: win.parse(text)
    }
  }

  Timer {
    id: typing
    interval: 120
    onTriggered: win.filter()
  }

  Timer {
    id: noteTimer
    interval: 1500
    onTriggered: win.note = ""
  }

  Column {
    anchors.fill: parent
    spacing: 8

    Rectangle {
      width: parent.width
      height: 34
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: search.activeFocus ? Theme.yellow : Theme.fgDim

      Text {
        anchors { fill: parent; leftMargin: 10 }
        verticalAlignment: Text.AlignVCenter
        visible: search.text === ""
        text: scan.running ? "LOADING ICONS..." : "SEARCH " + win.all.length + " ICONS"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize
      }

      TextInput {
        id: search
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fg
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize + 1
        onTextChanged: typing.restart()
        onAccepted: {
          if (win.current)
            win.copy(win.current.name, win.current.name);
        }
        Keys.onDownPressed: if (win.picked < win.shown.length - 1) win.picked += 1
        Keys.onUpPressed: if (win.picked > 0) win.picked -= 1
      }
    }

    // ---- the results ----
    GridView {
      id: grid
      width: parent.width
      height: parent.height - 34 - 8 - footer.height - 8
      clip: true
      cellWidth: Math.floor(width / 5)
      cellHeight: 78
      model: win.shown
      boundsBehavior: Flickable.StopAtBounds
      currentIndex: win.picked

      delegate: Item {
        required property var modelData
        required property int index

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
          anchors { fill: parent; margins: 2 }
          radius: Retro.corner
          color: hit.containsMouse || win.picked === index ? Theme.bgSel : "transparent"
          border.width: win.picked === index ? Retro.borderWidth : 0
          border.color: Theme.orange

          Image {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
            width: 40
            height: 40
            sourceSize: Qt.size(80, 80)
            asynchronous: true
            source: "file://" + modelData.path
          }

          Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 3 }
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: modelData.name
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 3
          }
        }

        MouseArea {
          id: hit
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            win.picked = index;
            win.copy(modelData.name, modelData.name);
          }
        }
      }
    }

    // ---- what is picked ----
    Column {
      id: footer
      width: parent.width
      spacing: 6

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: win.note !== "" ? win.note : (win.current ? win.current.name : "NOTHING PICKED")
        color: win.note !== "" ? Theme.green : Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize
      }

      Text {
        width: parent.width
        elide: Text.ElideMiddle
        text: win.current ? win.current.path : (win.shown.length >= win.maxShown ? "SHOWING THE FIRST " + win.maxShown : win.shown.length + " MATCHES")
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }

      Row {
        spacing: 8

        MiniButton {
          text: "COPY NAME"
          onClicked: if (win.current) win.copy(win.current.name, "NAME")
        }

        MiniButton {
          text: "COPY PATH"
          onClicked: if (win.current) win.copy(win.current.path, "PATH")
        }
      }
    }
  }
}
