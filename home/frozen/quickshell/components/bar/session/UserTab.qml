import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import "../calendar"

// The USER tab: you (picture, fingerprint), the switches, your status apps, and the full notification history.
Item {
  id: tab

  property var window: null             // the session window's own window (the tray menus need it)
  property bool choosing: false
  property bool fingerprinting: false

  Column {
    id: top
    width: parent.width
    spacing: 10

    UserCard {
      width: parent.width
      choosing: tab.choosing
      fingerprinting: tab.fingerprinting
      onFingerprintClicked: {
        tab.fingerprinting = !tab.fingerprinting;
        if (tab.fingerprinting)
          FingerprintState.refresh();
      }
      onChooseClicked: {
        tab.choosing = !tab.choosing;
        if (tab.choosing)
          SessionState.scanPictures();
      }
    }

    FingerprintPanel {
      width: parent.width
      visible: tab.fingerprinting
    }

    IconChooser {
      width: parent.width
      visible: tab.choosing
      onPicked: tab.choosing = false
    }

    Row {
      spacing: 8
      Tile {
        width: (top.width - 16) / 3
        implicitHeight: 46
        glyph: NotifStore.silent ? Glyphs.bellOff : Glyphs.bell
        label: "SILENT"
        sub: NotifStore.silent ? "ON" : "OFF"
        active: NotifStore.silent
        onActivated: NotifStore.silent = !NotifStore.silent
      }
      Tile {
        width: (top.width - 16) / 3
        implicitHeight: 46
        glyph: Sounds.enabled ? Glyphs.volHigh : Glyphs.volOff
        label: "SOUNDS"
        sub: Sounds.enabled ? "ON" : "OFF"
        active: Sounds.enabled
        onActivated: Sounds.toggle()
      }
      Tile {
        width: (top.width - 16) / 3
        implicitHeight: 46
        glyph: Glyphs.coffee
        label: "STAY AWAKE"
        sub: SessionState.stayAwake ? "AWAKE" : "NORMAL"
        active: SessionState.stayAwake
        onActivated: SessionState.stayAwake = !SessionState.stayAwake
      }
    }

    TrayPanel {
      width: parent.width
      window: tab.window
    }
  }

  NotificationPanel {
    anchors { left: parent.left; right: parent.right; top: top.bottom; topMargin: 12; bottom: parent.bottom }
  }
}
