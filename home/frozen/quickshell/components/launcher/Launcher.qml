import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.components.shared

Scope {
  id: root

  property bool open: false
  property bool pinned: false        // pinned: stays open when it loses focus
  onOpenChanged: {
    LauncherState.open = open;
    if (!open)
      pinned = false;
  }
  onPinnedChanged: LauncherState.pinned = pinned

  // ---- retro look (shared with the dock) ----

  // ---- panel size (the Hyprland rule in hyprland.lua places it above the dock) ----
  readonly property real panelWidth: 640
  readonly property real panelHeight: 520

  function show() {
    open = true;
  }
  function close() {
    open = false;
  }
  function toggle() {
    open ? close() : show();
  }

  // qs ipc call launcher toggle
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      root.toggle();
    }
    function open(): void {
      root.show();
    }
    function close(): void {
      root.close();
    }
  }
  // the dock was hidden by hand: an unpinned launcher closes, a pinned one just hides
  Connections {
    target: LauncherState

    function onDockHiddenChanged() {
      if (LauncherState.dockHidden && root.open && !root.pinned)
        root.close();
    }
  }

  // ---- pinned apps, saved in Quickshell's state folder ----
  FileView {
    id: pinFile
    path: Quickshell.statePath("pinned-apps.json")
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
        writeAdapter();
    }

    JsonAdapter {
      id: pins
      property list<string> ids: []
    }
  }

  // ---- the order you gave each other list, by dragging ----
  // One text value holding { "Internet": [ids], ... }. Pinned keeps its own order (pins.ids above) and
  // All Applications is always alphabetical, so neither is stored here.
  FileView {
    id: orderFile
    path: Quickshell.statePath("launcher-order.json")
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
        writeAdapter();
    }

    JsonAdapter {
      id: orders
      property string lists: "{}"
    }
  }

  function listOrder(name) {
    try {
      return JSON.parse(orders.lists)[name] || [];
    } catch (e) {
      return [];
    }
  }

  function saveListOrder(name, ids) {
    let all = {};
    try {
      all = JSON.parse(orders.lists);
    } catch (e) {}
    all[name] = ids;
    orders.lists = JSON.stringify(all);
  }

  // entries you placed come first in your order, everything else follows alphabetically
  function applyOrder(items, ids) {
    const rank = e => ids.indexOf(e.id);
    return items.slice().sort((a, b) => {
      const ra = rank(a);
      const rb = rank(b);
      if (ra < 0 && rb < 0)
        return a.name.localeCompare(b.name);
      if (ra < 0)
        return 1;
      if (rb < 0)
        return -1;
      return ra - rb;
    });
  }

  function isPinned(entry) {
    return pins.ids.indexOf(entry.id) !== -1;
  }

  function togglePin(entry) {
    const ids = Array.from(pins.ids);
    const i = ids.indexOf(entry.id);
    if (i >= 0)
      ids.splice(i, 1);
    else
      ids.push(entry.id);
    pins.ids = ids;
  }

  // the app's own categories plus the ones given in settings.nix (appCategories)
  function tagsOf(entry) {
    const extra = Settings.appCategories ? Settings.appCategories[entry.id] : null;
    return Array.from(entry.categories || []).concat(extra || []);
  }

  // Sidebar categories: freedesktop category tags per entry
  readonly property var categories: [
    {
      name: "Pinned",
      icon: "\uf005",
      pinned: true,
      tags: null
    },
    {
      name: "All Applications",
      icon: "\uf009",
      pinned: false,
      tags: null
    },
    {
      name: "Internet",
      icon: "\uf0ac",
      pinned: false,
      tags: ["Network", "WebBrowser", "Email", "InstantMessaging"]
    },
    {
      name: "Graphics",
      icon: "\uf1fc",
      pinned: false,
      tags: ["Graphics"]
    },
    {
      name: "Games",
      icon: "\uf11b",
      pinned: false,
      tags: ["Game"]
    },
    {
      name: "Steam Games",
      icon: "\uf1b6",
      pinned: false,
      tags: ["Steam"]
    },
    {
      name: "Multimedia",
      icon: "\uf001",
      pinned: false,
      tags: ["AudioVideo", "Audio", "Video"]
    },
    {
      name: "Development",
      icon: "\uf121",
      pinned: false,
      tags: ["Development"]
    },
    {
      name: "Office",
      icon: "\uf0b1",
      pinned: false,
      tags: ["Office"]
    },
    {
      name: "System",
      icon: "\uf013",
      pinned: false,
      tags: ["System", "Settings"]
    },
    {
      name: "Utilities",
      icon: "\uf0ad",
      pinned: false,
      tags: ["Utility"]
    }
  ]

  // The launcher is a normal floating window. The title is what the Hyprland rule matches.
  FloatingWindow {
    id: win
    title: "qs-launcher"
    visible: root.open && !LauncherState.dockHidden
    color: "transparent"

    implicitWidth: root.panelWidth + Retro.shadowOffset
    implicitHeight: root.panelHeight + Retro.shadowOffset
    minimumSize: Qt.size(implicitWidth, implicitHeight)
    maximumSize: Qt.size(implicitWidth, implicitHeight)

    property int catIndex: 0

    // true once the window has had the keyboard, so it isn't closed before it ever got it
    property bool hadFocus: false

    // Watches whether this window has the keyboard. Not pinned: losing it (you clicked
    // another window) closes the launcher, like KDE's. Pinned: it just stays open.
    Item {
      id: focusWatcher
      readonly property bool focused: Window.active

      Window.onActiveChanged: {
        if (Window.active) {
          win.hadFocus = true;
          search.forceActiveFocus();       // the window has the keyboard now: put the cursor in the box
        } else if (win.hadFocus && root.open && !root.pinned) {
          root.close();
        }
      }
    }

    // ---- calculator state ----
    property string calcExpr: ""
    property string calcResult: ""
    readonly property bool calcShown: calcExpr !== "" && calcResult !== ""

    // Returns the expression to calculate, or "" if the text isn't math.
    // Plain arithmetic is detected automatically; start with "=" for anything else
    // (functions, units, conversions: "=sqrt(2)", "=5 km to miles").
    function mathExpr(text) {
      const q = text.trim();
      if (q.startsWith("="))
        return q.slice(1).trim();
      if (/^[0-9(.\-][0-9\s.,()+\-*\/^%]*$/.test(q) && /[+\-*\/^%]/.test(q.slice(1)))
        return q;
      return "";
    }

    function runCalc() {
      if (calcExpr === "")
        return;
      if (calc.running) {
        calcTimer.restart();
        return;
      }
      calc.command = [Tools.qalc, "-t", calcExpr];
      calc.running = true;
    }

    function copyResult() {
      Quickshell.execDetached([Tools.wlCopy, calcResult]);
      if (!root.pinned)
        root.close();
    }

    // ---- results ----
    readonly property var apps: {
      const q = search.text.trim().toLowerCase();
      const cat = root.categories[catIndex];
      const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);

      if (q !== "") {
        // searching looks through every category
        return all.filter(e => {
          const hay = (e.name + " " + (e.genericName || "") + " " + (e.comment || "") + " " + (e.keywords || []).join(" ")).toLowerCase();
          return hay.indexOf(q) !== -1;
        }).sort((a, b) => {
          const ap = a.name.toLowerCase().startsWith(q) ? 0 : 1;
          const bp = b.name.toLowerCase().startsWith(q) ? 0 : 1;
          if (ap !== bp)
            return ap - bp;
          return a.name.localeCompare(b.name);
        });
      }

      if (cat.pinned) {
        // keep the order you pinned them in
        return Array.from(pins.ids).map(id => all.find(e => e.id === id)).filter(e => e !== undefined);
      }

      const inCategory = all.filter(e => cat.tags === null || cat.tags.some(t => root.tagsOf(e).indexOf(t) !== -1)).sort((a, b) => a.name.localeCompare(b.name));
      return cat.tags === null ? inCategory : root.applyOrder(inCategory, root.listOrder(cat.name));
    }

    // keepOpen (middle click): start the app but leave the launcher up, to start several in a row
    function launch(entry, keepOpen) {
      entry.execute();
      if (!root.pinned && !keepOpen)
        root.close();
    }

    // Lists you can reorder by dragging: Pinned and every category except All Applications.
    // Not while searching, since a search result is not one of those lists.
    readonly property bool canReorder: search.text === "" && (root.categories[catIndex].pinned || root.categories[catIndex].tags !== null)

    // move the entry at index `from` to the drop slot `slot` (0 = above the first row, apps.length = below the last)
    function moveEntry(from, slot) {
      const to = slot > from ? slot - 1 : slot;
      if (to === from)
        return;
      const ids = win.apps.map(e => e.id);
      ids.splice(to, 0, ids.splice(from, 1)[0]);
      const cat = root.categories[catIndex];
      if (cat.pinned)
        pins.ids = ids;
      else
        root.saveListOrder(cat.name, ids);
    }

    // Right click / Ctrl+Enter: show the app's window on this workspace, or start it if it is not open
    function focusOrLaunch(entry) {
      if (!AppWindows.focus(entry))
        entry.execute();
      if (!root.pinned)
        root.close();
    }

    // true while the text is a search for apps (not a calculation, ?web search, >command or :emoji)
    readonly property bool appMode: !emoji.active && !calcShown && !search.text.trim().startsWith("?") && !search.text.trim().startsWith(">")

    function launchCurrent(keepOpen) {
      const e = apps[list.currentIndex];
      if (e)
        launch(e, keepOpen === true);
    }

    function focusCurrent() {
      const e = apps[list.currentIndex];
      if (e)
        focusOrLaunch(e);
    }

    function pinCurrent() {
      const e = apps[list.currentIndex];
      if (e)
        root.togglePin(e);
    }

    function webSearch(query) {
      const url = "https://duckduckgo.com/?q=" + encodeURIComponent(query);
      Quickshell.execDetached(["xdg-open", url]);
      root.close();
    }

    function runTerminal(command) {
      Quickshell.execDetached(["sh", "-c", command]);
      root.close();
    }

    // start fresh only when the launcher is opened, not when it comes back after hiding
    Connections {
      target: root

      function onOpenChanged() {
        if (root.open) {
          win.hadFocus = false;
          search.text = "";
          win.catIndex = pins.ids.length > 0 ? 0 : 1;
          list.currentIndex = 0;
          win.calcExpr = "";
          win.calcResult = "";
        }
      }
    }

    onVisibleChanged: {
      if (visible) {
        hadFocus = false;
        search.forceActiveFocus();
        focusTimer.restart();
      } else if (root.open && !LauncherState.dockHidden) {
        // closed from outside (for example with the close-window keybind)
        root.open = false;
      }
    }

    // Shortly after opening: make sure the search box has the cursor, and if the window did not get the
    // keyboard by itself (nothing else open on the workspace), ask Hyprland to give it.
    Timer {
      id: focusTimer
      interval: 80
      onTriggered: {
        search.forceActiveFocus();
        if (!focusWatcher.focused)
          Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "title:^qs-launcher$" })']);
      }
    }

    // hard drop shadow
    Rectangle {
      x: Retro.shadowOffset
      y: Retro.shadowOffset
      width: panel.width
      height: panel.height
      radius: Retro.corner
      color: Retro.shadowColor
    }

    // ================= the window =================
    Rectangle {
      id: panel
      x: 0
      y: 0
      width: root.panelWidth
      height: root.panelHeight
      radius: Retro.corner
      color: Theme.bg
      border.color: Theme.fg
      border.width: Retro.borderWidth

      // swallow clicks on empty panel areas
      MouseArea {
        anchors.fill: parent
      }

      // calculator plumbing
      Timer {
        id: calcTimer
        interval: 120
        repeat: false
        onTriggered: win.runCalc()
      }

      Process {
        id: calc
        stdout: StdioCollector {
          onStreamFinished: {
            // ignore answers for an expression that has since changed
            if (calc.command[2] === win.calcExpr)
              win.calcResult = text.trim();
            else
              calcTimer.restart();
          }
        }
      }

      TitleBar {
        id: titleBar
        title: "Launcher"
        height: 18
        showPin: true
        pinned: root.pinned
        onPinClicked: root.pinned = !root.pinned
        onCloseClicked: root.close()
      }

      // ---- search: >_ ----
      Rectangle {
        id: searchBox
        anchors {
          left: parent.left
          right: parent.right
          top: titleBar.bottom
          leftMargin: 12
          rightMargin: 12
          topMargin: 10
        }
        height: 38
        radius: Retro.corner
        color: Retro.inset

        // yellow while the launcher has the keyboard, gray while another window does
        border.color: focusWatcher.focused ? Theme.yellow : Theme.fgDim
        border.width: Retro.borderWidth

        Text {
          id: prompt
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 12
          }
          text: ">_"
          color: Theme.yellow
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 1
        }

        Text {
          anchors {
            left: prompt.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10
          }
          visible: search.text === ""
          text: "search | =calc | ?google | >command | :emoji"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize
        }

        TextInput {
          id: search
          anchors {
            left: prompt.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 12
          }
          verticalAlignment: TextInput.AlignVCenter
          color: Theme.fg
          selectByMouse: true
          clip: true
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize + 1

          onTextChanged: {
            list.currentIndex = 0;
            win.calcExpr = win.mathExpr(text);
            if (win.calcExpr === "")
              win.calcResult = "";
            else
              calcTimer.restart();
          }

          onAccepted: {
            const q = text.trim();

            if (emoji.active) {
              emoji.accept();
              return;
            }

            if (q.startsWith("?")) {
              const query = q.slice(1).trim();
              if (query !== "")
                win.webSearch(query);
            } else if (q.startsWith(">")) {
              const command = q.slice(1).trim();
              if (command !== "")
                win.runTerminal(command);
            } else if (win.calcShown) {
              win.copyResult();
            } else {
              win.launchCurrent();
            }
          }

          // pinned launchers ignore Esc (use the x); otherwise it closes
          Keys.onEscapePressed: {
            if (!root.pinned)
              root.close();
          }
          // Enter starts the app. Shift+Enter starts a new window and keeps the launcher open,
          // Ctrl+Enter shows the open window instead, Ctrl+P pins or unpins.
          Keys.onPressed: event => {
            if (!win.appMode)
              return;
            const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;

            if (enter && (event.modifiers & Qt.ControlModifier)) {
              win.focusCurrent();
              event.accepted = true;
            } else if (enter && (event.modifiers & Qt.ShiftModifier)) {
              win.launchCurrent(true);
              event.accepted = true;
            } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
              win.pinCurrent();
              event.accepted = true;
            }
          }
          Keys.onDownPressed: emoji.active ? emoji.next() : list.incrementCurrentIndex()
          Keys.onUpPressed: emoji.active ? emoji.previous() : list.decrementCurrentIndex()
        }
      }

      // ---- category sidebar ----
      // scrolls with the wheel when there are more categories than fit
      Flickable {
        id: sidebar
        anchors {
          left: parent.left
          top: searchBox.bottom
          bottom: parent.bottom
          leftMargin: 12
          topMargin: 10
          bottomMargin: 12
        }
        width: 168
        clip: true
        interactive: false
        contentWidth: width
        contentHeight: catColumn.implicitHeight + 2      // 2: the raised shadow under the last button
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: catColumn
          spacing: 4

          Repeater {
            model: root.categories

            Item {
              id: catButton
              required property var modelData
              required property int index

              readonly property bool selected: win.catIndex === index && search.text === ""

              width: sidebar.width - 2
              height: 34

              // raised shadow: always present unless selected
              Rectangle {
                x: 2
                y: 2
                width: parent.width
                height: parent.height
                radius: Retro.corner
                color: Retro.shadowColor
                visible: !catButton.selected
              }

              // selected entries match the focused dock button
              Rectangle {
                anchors.fill: parent
                radius: Retro.corner
                color: catButton.selected ? Theme.bgSel : Theme.bgAlt
              }

              Text {
                id: catIcon
                anchors {
                  left: parent.left
                  verticalCenter: parent.verticalCenter
                  leftMargin: 10
                }
                width: 18
                horizontalAlignment: Text.AlignHCenter
                text: catButton.modelData.icon
                color: catButton.selected ? Theme.yellow : Theme.fgDim
                font.family: Theme.fontMono
                font.pointSize: Theme.fontSize + 1
              }

              Text {
                anchors {
                  left: catIcon.right
                  verticalCenter: parent.verticalCenter
                  leftMargin: 10
                }
                text: catButton.modelData.name
                color: Theme.fg
                font.family: Theme.fontSans
                font.bold: catButton.selected
                font.pointSize: Theme.fontSize
              }

              MouseArea {
                id: catMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  win.catIndex = catButton.index;
                  search.text = "";
                  list.currentIndex = 0;
                  search.forceActiveFocus();
                }
              }
            }
          }
        }
      }

      WheelScroll {
        anchors.fill: sidebar
        view: sidebar
        notchPixels: 60
      }

      // groove between the sidebar and the list
      Rectangle {
        id: divider
        anchors {
          left: sidebar.right
          top: sidebar.top
          bottom: sidebar.bottom
          leftMargin: 6
        }
        width: 2
        color: Theme.fgDim
      }

      // ---- calculator result card ----
      Rectangle {
        id: calcCard
        visible: win.calcShown
        anchors {
          left: divider.right
          right: parent.right
          top: searchBox.bottom
          leftMargin: 8
          rightMargin: 12
          topMargin: 10
        }
        height: visible ? 64 : 0
        radius: Retro.corner
        color: Retro.inset
        border.color: Theme.yellow
        border.width: Retro.borderWidth

        Column {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 14
          }
          spacing: 8

          Text {
            text: win.calcExpr
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 1
          }
          Text {
            text: "= " + win.calcResult
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize + 5
          }
        }

        Text {
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 14
          }
          text: "ENTER = COPY"
          color: Theme.yellow
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        MouseArea {
          anchors.fill: parent
          onClicked: win.copyResult()
        }
      }

      // ---- emoji search: ":fire heart" ----
      EmojiPicker {
        id: emoji
        z: 10                      // above the app list, which would otherwise take the clicks
        visible: active
        query: search.text
        anchors {
          left: divider.right
          right: parent.right
          top: searchBox.bottom
          bottom: parent.bottom
          leftMargin: 8
          rightMargin: 12
          topMargin: 10
          bottomMargin: 12
        }
        onCopied: {
          if (!root.pinned)
            root.close();
        }
      }

      // ---- app list ----
      ListView {
        id: list
        anchors {
          left: divider.right
          right: parent.right
          top: calcCard.visible ? calcCard.bottom : searchBox.bottom
          bottom: parent.bottom
          leftMargin: 8
          rightMargin: 12
          topMargin: 10
          bottomMargin: 12
        }
        clip: true
        spacing: 6
        model: win.apps
        currentIndex: 0
        boundsBehavior: Flickable.StopAtBounds
        interactive: false          // dragging a row is for reordering; the wheel and the bar scroll
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        // dragging a row to a new place: which row, the drop slot, and where the pointer is in the list
        property int dragFrom: -1
        property int dragSlot: 0
        property real dragViewY: 0
        readonly property real rowStep: 47 + spacing            // row height plus gap

        // keep scrolling while a row is held near the top or bottom edge
        Timer {
          running: list.dragFrom >= 0
          interval: 16
          repeat: true
          onTriggered: {
            const edge = 36;
            const max = Math.max(0, list.contentHeight - list.height);
            if (list.dragViewY < edge)
              list.contentY = Math.max(0, list.contentY - 8);
            else if (list.dragViewY > list.height - edge)
              list.contentY = Math.min(max, list.contentY + 8);
          }
        }

        delegate: Item {
          id: appRow
          required property var modelData
          required property int index

          readonly property bool selected: ListView.isCurrentItem

          width: ListView.view.width - 2
          height: 47
          opacity: list.dragFrom === appRow.index ? 0.35 : 1

          // raised shadow: always present unless selected
          Rectangle {
            x: 2
            y: 2
            width: parent.width
            height: parent.height
            radius: Retro.corner
            color: Retro.shadowColor
            visible: !appRow.selected
          }

          // selected entries match the focused dock button
          Rectangle {
            anchors.fill: parent
            radius: Retro.corner
            color: appRow.selected ? Theme.bgSel : Theme.bgAlt
          }

          Image {
            id: appIcon
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
              leftMargin: 10
            }
            width: 29
            height: 29
            sourceSize.width: 58
            sourceSize.height: 58
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            source: {
              const ic = appRow.modelData.icon || "";
              if (ic.startsWith("/"))
                return "file://" + ic;
              return Quickshell.iconPath(ic, true) || Quickshell.iconPath("application-x-executable");
            }
          }

          Column {
            anchors {
              left: appIcon.right
              right: parent.right
              verticalCenter: parent.verticalCenter
              leftMargin: 12
              rightMargin: 34
            }
            spacing: 1

            Text {
              width: parent.width
              elide: Text.ElideRight
              text: appRow.modelData.name
              color: Theme.fg
              font.family: Theme.fontSans
              font.bold: true
              font.pointSize: (Theme.fontSize + 1) * 0.9
            }

            Text {
              width: parent.width
              elide: Text.ElideRight
              visible: text !== ""
              text: appRow.modelData.genericName || appRow.modelData.comment || ""
              color: Qt.lighter(Theme.fgDim, 1.3)
              font.family: Theme.fontSans
              font.pointSize: (Theme.fontSize - 1) * 0.9
            }
          }

          // pin star: filled when pinned, an outline while the row is hovered. Click it to pin or unpin.
          MouseArea {
            id: starMouse
            z: 2
            anchors {
              right: parent.right
              top: parent.top
              bottom: parent.bottom
            }
            width: 36
            hoverEnabled: true
            onClicked: root.togglePin(appRow.modelData)

            Text {
              anchors.centerIn: parent
              visible: root.isPinned(appRow.modelData) || rowMouse.containsMouse || starMouse.containsMouse
              text: root.isPinned(appRow.modelData) ? "★" : "☆"
              color: root.isPinned(appRow.modelData) ? Theme.yellow : Theme.fgDim
              font.pointSize: Theme.fontSize + 2
            }
          }

          // left: start (or drag to reorder), middle: start a new window and keep the launcher open,
          // right: show the open window of the app, or start it
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            property real pressY: 0
            property bool dragging: false
            property bool moved: false           // true once a press turned into a drag, so the release is not a click

            onPressed: mouse => {
              pressY = mouse.y;
              dragging = false;
              moved = false;
            }

            onPositionChanged: mouse => {
              if (!pressed) {
                list.currentIndex = appRow.index;
                return;
              }
              if (!(pressedButtons & Qt.LeftButton) || !win.canReorder)
                return;
              if (!dragging && Math.abs(mouse.y - pressY) > 8) {
                dragging = true;
                moved = true;
                list.dragFrom = appRow.index;
              }
              if (dragging) {
                const p = mapToItem(list, mouse.x, mouse.y);
                list.dragViewY = p.y;
                list.dragSlot = Math.max(0, Math.min(win.apps.length, Math.round((p.y + list.contentY) / list.rowStep)));
              }
            }

            // the carried copy is cleared first: moving the entry rebuilds the list and destroys this row
            onReleased: {
              const from = list.dragFrom;
              const slot = list.dragSlot;
              const wasDragging = dragging;
              dragging = false;
              list.dragFrom = -1;
              if (wasDragging)
                win.moveEntry(from, slot);
            }

            onCanceled: {
              dragging = false;
              list.dragFrom = -1;
            }

            onClicked: mouse => {
              if (moved)
                return;
              if (mouse.button === Qt.RightButton)
                win.focusOrLaunch(appRow.modelData);
              else if (mouse.button === Qt.MiddleButton)
                win.launch(appRow.modelData, true);
              else
                win.launch(appRow.modelData, false);
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: win.apps.length === 0 && !win.calcShown && !emoji.active
          text: (win.catIndex === 0 && search.text === "") ? "NOTHING PINNED YET. CLICK THE STAR ON AN APP TO PIN IT." : "NO APPLICATIONS FOUND"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      // while dragging: a line where the row will land, and a copy of the row under the pointer
      Rectangle {
        id: dropLine
        visible: list.dragFrom >= 0
        x: list.x
        width: list.width - 2
        height: 3
        radius: 1
        color: Theme.orange
        y: list.y + Math.max(0, Math.min(list.height, list.dragSlot * list.rowStep - list.contentY)) - 4
        z: 50
      }

      Rectangle {
        id: carried
        visible: list.dragFrom >= 0
        x: list.x
        width: list.width - 2
        height: 47
        y: list.y + list.dragViewY - height / 2
        radius: Retro.corner
        color: Theme.bgSel
        border.width: Retro.borderWidth
        border.color: Theme.orange
        z: 60

        Text {
          anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
          elide: Text.ElideRight
          text: list.dragFrom >= 0 && win.apps[list.dragFrom] ? win.apps[list.dragFrom].name : ""
          color: Theme.fg
          font.family: Theme.fontSans
          font.bold: true
          font.pointSize: (Theme.fontSize + 1) * 0.9
        }
      }

      // faster wheel scrolling (notchPixels: pixels per wheel notch)
      WheelScroll {
        anchors.fill: list
        view: list
        notchPixels: 90
      }

      RetroScrollBar {
        target: list
        anchors { left: list.right; leftMargin: 3; top: list.top; bottom: list.bottom }
      }

      // A click anywhere inside the launcher puts the text cursor back in the search box.
      // It sits on top of everything and lets the click through to whatever is underneath.
      MouseArea {
        z: 100
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons

        onPressed: mouse => {
          search.forceActiveFocus();
          mouse.accepted = false;
        }
      }
    }
  }
}
