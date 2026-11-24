import QtQuick
import qs
import qs.components.bar.tools
import qs.components.bar.audio
import qs.components.bar.connections
import qs.components.bar.display
import qs.components.bar.session
import qs.components.bar.studio

// The group of tool buttons (AI, audio, display, connections, session), each followed by a separator, and the windows they open.
// Studio comes first: a wide song key and a play/pause key (StudioBarGroup), then the volume key and the rest.
// Every window here is a "right" popup (name starts with "tool-"), so only one is open at a time, and
// none can be open together with the calendar or the AI window. To add a tool: a button below, a window
// under it, and nothing else.
Item {
  id: section

  property string openName: ""          // the bar's right popup
  property bool pinned: false
  property bool held: false
  property real studioWidth: 160        // width of the song key, set by the bar (BarRight)

  // everything in this section except the song key; BarRight subtracts it to size the key
  readonly property real fixedWidth: tools.implicitWidth + studio.fixedWidth + studioEnd.width

  signal toggle(string name)
  signal closeRequested(string name)
  signal pinToggled

  implicitWidth: buttons.implicitWidth
  implicitHeight: 22
  width: implicitWidth
  height: implicitHeight

  Row {
    id: buttons
    spacing: 0

    // ---- studio: the song, then play/pause ----
    StudioBarGroup {
      id: studio
      anchors.verticalCenter: parent.verticalCenter
      open: section.openName === "tool-studio"
      nameWidth: section.studioWidth
      onToggle: section.toggle("tool-studio")
    }
    BarSep { id: studioEnd; padLeft: 5; padRight: 7 }

    Row {
      id: tools
      spacing: 0

      // ---- microphone: orange while an app is recording, red when muted. Middle click = mute, wheel = mic
      // volume (both show the mic indicator). A click opens the AI window (the key is pressed in while it
      // shows); end its program from the arrow tab in that window (middle click) or: qs ipc call ai stop ----
      ToolButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: AudioState.micMuted ? Glyphs.micOff : Glyphs.mic
        tint: AudioState.micMuted ? Theme.red : (AudioState.micInUse ? Theme.orange : Theme.fg)
        open: AiState.open
        onClicked: section.toggle("ai")
        onMiddleClicked: AudioState.toggleMicMuted()
        onScrolled: dir => AudioState.nudgeMic(dir * 0.05)
      }
      BarSep { padLeft: 5; padRight: 7 }

      // ---- audio ----
      ToolButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: AudioState.icon
        tint: AudioState.muted ? Theme.red : Theme.fg
        open: section.openName === "tool-audio"
        onClicked: section.toggle("tool-audio")
        onMiddleClicked: AudioState.setMuted(!AudioState.muted)
        onScrolled: dir => AudioState.nudge(dir * 0.05)
      }
      BarSep { padLeft: 5; padRight: 7 }

      // ---- display: a bulb that fills with brightness. Middle click = laptop screen off, wheel = every monitor ----
      ToolButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: DisplayState.bulb(DisplayState.currentLevel)
        tint: DisplayState.laptopHidden ? Theme.orange : Theme.fg
        open: section.openName === "tool-display"
        onClicked: section.toggle("tool-display")
        onMiddleClicked: DisplayState.setLaptopHidden(!DisplayState.laptopHidden)
        onScrolled: dir => DisplayState.nudgeAll(dir)
      }
      BarSep { padLeft: 5; padRight: 7 }

      // ---- connections: airplane > VPN > Wi-Fi strength. Middle click = VPN on/off ----
      ToolButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: NetState.barGlyph
        tint: NetState.barTint
        open: section.openName === "tool-connections"
        onClicked: section.toggle("tool-connections")
        onMiddleClicked: NetState.vpnToggle()
      }
      BarSep { padLeft: 5; padRight: 7 }

      // ---- session (last: the line before the clock is BarRight's `gap`) ----
      ToolButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: NotifStore.silent ? Glyphs.bellOff : (NotifStore.unread > 0 ? Glyphs.bellRing : Glyphs.bell)
        tint: NotifStore.silent ? Theme.orange : Theme.fg
        dot: NotifStore.unread > 0 && !NotifStore.silent
        open: section.openName === "tool-session"
        onClicked: section.toggle("tool-session")
        onMiddleClicked: NotifStore.silent = !NotifStore.silent
      }
    }
  }

  // ---- the windows ----
  ConnectionsWindow {
    open: section.openName === "tool-connections"
    pinned: section.pinned
    held: section.held
    onCloseRequested: section.closeRequested("tool-connections")
    onPinToggled: section.pinToggled()
  }

  DisplayWindow {
    open: section.openName === "tool-display"
    pinned: section.pinned
    held: section.held
    onCloseRequested: section.closeRequested("tool-display")
    onPinToggled: section.pinToggled()
  }

  AudioWindow {
    open: section.openName === "tool-audio"
    pinned: section.pinned
    held: section.held
    onCloseRequested: section.closeRequested("tool-audio")
    onPinToggled: section.pinToggled()
  }

  SessionWindow {
    open: section.openName === "tool-session"
    pinned: section.pinned
    held: section.held
    onCloseRequested: section.closeRequested("tool-session")
    onPinToggled: section.pinToggled()
  }

  StudioWindow {
    open: section.openName === "tool-studio"
    pinned: section.pinned
    held: section.held
    onCloseRequested: section.closeRequested("tool-studio")
    onPinToggled: section.pinToggled()
  }

  // a screenshot is taken without this window in it
  Connections {
    target: StudioState

    function onRevealRequested() {
      if (section.openName !== "tool-studio")
        section.toggle("tool-studio");
    }

    function onAboutToCapture() {
      if (section.openName === "tool-studio" && !section.pinned)
        section.closeRequested("tool-studio");
    }
  }
}
