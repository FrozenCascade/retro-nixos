import QtQuick
import QtQuick.Window
import QtCore
import QtWebEngine

// The AI window: a provider selector, browser buttons and the page. Same retro frame as the shell.
// The Hyprland rule "qs-ai" (hyprland.lua) must be this size: frame 520 x 740 plus the 4 px shadow.
Window {
  id: win

  title: "qs-ai"
  width: 524
  height: 744
  minimumWidth: width
  maximumWidth: width
  minimumHeight: height
  maximumHeight: height
  visible: true
  color: "transparent"
  flags: Qt.Window | Qt.FramelessWindowHint

  // the shell's colors arrive from Quickshell; these are only used if it did not send any
  readonly property var c: Object.assign({
    bg: "#282828", bgAlt: "#3c3836", bgSel: "#504945", fg: "#ebdbb2", fgDim: "#a89984",
    orange: "#fe8019", yellow: "#fabd2f", red: "#fb4934", green: "#b8bb26", blue: "#83a598", aqua: "#8ec07c",
    fontMono: "monospace", fontSize: 10, corner: 3, border: 2, shadow: 4, shadowColor: "#99000000", inset: "#59000000"
  }, JSON.parse(themeJson))

  readonly property var providers: [
    { id: "duck", name: "DUCK AI", home: "https://duck.ai/" },
    { id: "pplx", name: "PERPLEXITY", home: "https://www.perplexity.ai/" },
    { id: "claude", name: "CLAUDE", home: "https://claude.ai/new" }
  ]

  property bool hadFocus: false

  // remembered between runs: the provider, the last page of each, zoom and the pin
  Settings {
    id: prefs
    category: "ai"
    property string provider: "claude"
    property string lastUrls: "{}"
    property real zoom: 1.0
    property bool pinned: true
  }

  function providerIndex() {
    for (let i = 0; i < providers.length; i++)
      if (providers[i].id === prefs.provider)
        return i;
    return 2;
  }

  function remember(u) {
    let m = {};
    try {
      m = JSON.parse(prefs.lastUrls);
    } catch (e) {}
    m[prefs.provider] = u;
    prefs.lastUrls = JSON.stringify(m);
  }

  // open the provider at the page it was last on
  function load(useHome) {
    const p = providers[providerIndex()];
    let m = {};
    try {
      m = JSON.parse(prefs.lastUrls);
    } catch (e) {}
    web.url = (!useHome && m[p.id]) ? m[p.id] : p.home;
  }

  function pick(i) {
    prefs.provider = providers[i].id;
    load(false);
  }

  // what you type in the address box: a link, a bare domain, or a search
  function normalize(text) {
    const t = text.trim();
    if (t === "")
      return "";
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t))
      return t;
    if (!/\s/.test(t) && /^[^\s\/]+\.[^\s\/]{2,}/.test(t))
      return "https://" + t;
    return "https://duckduckgo.com/?q=" + encodeURIComponent(t);
  }

  function zoomBy(d) {
    prefs.zoom = Math.max(0.5, Math.min(2.5, Math.round((prefs.zoom + d) * 10) / 10));
  }

  function show() {
    visible = true;
    raise();
    requestActivate();
  }

  // end the whole program (and its browser) to give the memory back; the next open starts a fresh one
  function endProgram() {
    visible = false;          // tells the bar the window is gone
    Qt.quit();
  }

  onVisibleChanged: {
    bridge.report(visible);
    if (visible)
      hadFocus = false;
  }

  // unpinned: leaving the window hides it, like the shell's other windows
  onActiveChanged: {
    if (active)
      hadFocus = true;
    else if (hadFocus && !prefs.pinned && visible)
      visible = false;
  }

  Connections {
    target: bridge
    function onToggleRequested() {
      if (win.visible)
        win.visible = false;
      else
        win.show();
    }
  }

  Component.onCompleted: load(false)

  Shortcut { sequence: "Ctrl+L"; onActivated: { address.forceActiveFocus(); address.selectAll(); } }
  Shortcut { sequence: "Ctrl+R"; onActivated: web.reload() }
  Shortcut { sequence: "F5"; onActivated: web.reload() }
  Shortcut { sequence: "Alt+Left"; onActivated: web.goBack() }
  Shortcut { sequence: "Alt+Right"; onActivated: web.goForward() }
  Shortcut { sequence: "Ctrl+W"; onActivated: win.visible = false }
  Shortcut { sequence: "Ctrl+1"; onActivated: win.pick(0) }
  Shortcut { sequence: "Ctrl+2"; onActivated: win.pick(1) }
  Shortcut { sequence: "Ctrl+3"; onActivated: win.pick(2) }
  Shortcut { sequence: "Ctrl+="; onActivated: win.zoomBy(0.1) }
  Shortcut { sequence: "Ctrl+-"; onActivated: win.zoomBy(-0.1) }
  Shortcut { sequence: "Ctrl+0"; onActivated: prefs.zoom = 1.0 }

  // the one browser profile all three providers share: logins survive restarts and shutdowns
  WebEngineProfile {
    id: profile
    storageName: "main"
    offTheRecord: false
    persistentStoragePath: dataDir + "/profile"
    cachePath: dataDir + "/cache"
    persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
  }

  // shadow, then the frame
  Rectangle {
    x: win.c.shadow
    y: win.c.shadow
    width: frame.width
    height: frame.height
    radius: win.c.corner
    color: win.c.shadowColor
  }

  Rectangle {
    id: frame
    width: 520
    height: 740
    radius: win.c.corner
    color: win.c.bg
    border.color: win.c.fg
    border.width: win.c.border

    // title bar: the same as the shell's TitleBar (light bar, "\\\ TITLE", [+] pin and [x] close)
    Rectangle {
      id: titleBar
      x: win.c.border
      y: win.c.border
      width: parent.width - win.c.border * 2
      height: 18
      color: win.c.fg

      Text {
        anchors { left: parent.left; right: titleButtons.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 6 }
        elide: Text.ElideRight
        text: "\\\\\\ AI"
        color: win.c.bg
        font.family: win.c.fontMono
        font.bold: true
        font.pointSize: win.c.fontSize - 1
      }

      Row {
        id: titleButtons
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
        spacing: 4
        TitleButton { c: win.c; text: "+"; active: prefs.pinned; onClicked: prefs.pinned = !prefs.pinned }
        TitleButton { c: win.c; text: "x"; onClicked: win.visible = false }
      }
    }

    // four tabs of equal width: the three providers, and one that opens the page in your normal browser
    // (middle click on that one ends the AI program)
    Row {
      id: providerRow
      x: 14
      y: 34
      width: parent.width - 28
      spacing: 8

      Repeater {
        model: win.providers
        delegate: RetroTab {
          required property var modelData
          required property int index
          c: win.c
          width: (providerRow.width - 24) / 4
          label: modelData.name
          selected: prefs.provider === modelData.id
          onClicked: win.pick(index)
        }
      }

      RetroTab { c: win.c; width: (providerRow.width - 24) / 4; label: "\u2197"; onClicked: bridge.openExternal(web.url.toString()); onMiddleClicked: win.endProgram() }
    }

    // browser buttons, the address box, and zoom on the right
    Item {
      id: navRow
      x: 14
      y: providerRow.y + providerRow.height + 8
      width: parent.width - 28
      height: 26

      Row {
        id: navLeft
        spacing: 4
        MiniButton { c: win.c; height: 26; text: "<"; enabled: web.canGoBack; onClicked: web.goBack() }
        MiniButton { c: win.c; height: 26; text: ">"; enabled: web.canGoForward; onClicked: web.goForward() }
        MiniButton { c: win.c; height: 26; text: web.loading ? "STOP" : "RELOAD"; onClicked: web.loading ? web.stop() : web.reload() }
        MiniButton { c: win.c; height: 26; text: "HOME"; onClicked: win.load(true) }
      }

      Row {
        id: navRight
        anchors.right: parent.right
        spacing: 4
        MiniButton { c: win.c; height: 26; text: "-"; onClicked: win.zoomBy(-0.1) }
        MiniButton { c: win.c; height: 26; width: 54; text: Math.round(prefs.zoom * 100) + "%"; onClicked: prefs.zoom = 1.0 }
        MiniButton { c: win.c; height: 26; text: "+"; onClicked: win.zoomBy(0.1) }
      }

      Rectangle {
        anchors { left: navLeft.right; right: navRight.left; leftMargin: 8; rightMargin: 8 }
        height: 26
        radius: win.c.corner
        color: win.c.inset
        border.width: win.c.border
        border.color: address.activeFocus ? win.c.yellow : win.c.fgDim

        TextInput {
          id: address
          anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          selectByMouse: true
          color: win.c.fg
          font.family: win.c.fontMono
          font.pointSize: win.c.fontSize - 1
          // follows the page unless you are typing
          text: activeFocus ? text : web.url.toString()
          onAccepted: {
            const u = win.normalize(text);
            if (u !== "")
              web.url = u;
            web.forceActiveFocus();
          }
          Keys.onEscapePressed: web.forceActiveFocus()
        }
      }
    }

    // the page, in a bordered well, all the way down to the frame's padding
    Rectangle {
      id: well
      x: 14
      y: navRow.y + navRow.height + 8
      width: parent.width - 28
      height: parent.height - y - 14
      radius: win.c.corner
      color: win.c.bg
      border.width: win.c.border
      border.color: win.c.fgDim

      WebEngineView {
        id: web
        anchors { fill: parent; margins: win.c.border }
        profile: profile
        zoomFactor: prefs.zoom
        onNewWindowRequested: request => request.openIn(web)
        onFullScreenRequested: request => request.reject()
        onLoadingChanged: loadingInfo => {
          if (loadingInfo.status === WebEngineView.LoadSucceededStatus)
            win.remember(web.url.toString());
        }
      }

      // loading bar along the top of the page
      Rectangle {
        x: win.c.border
        y: win.c.border
        width: (parent.width - win.c.border * 2) * web.loadProgress / 100
        height: 2
        color: win.c.orange
        visible: web.loading
      }
    }
  }
}
