pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/calendar.js" as Cal

// How long ago `nix flake update` last changed flake.lock (its file time), and the login reminder.
Singleton {
  id: root

  readonly property string lockPath: (Quickshell.env("HOME") || "") + "/nixos-config/flake.lock"
  property real lockMs: 0
  property bool checked: false
  property bool nagDone: false

  readonly property bool known: lockMs > 0
  readonly property real ageMs: known ? Math.max(0, Clock.nowMs - lockMs) : 0
  readonly property real ageDays: ageMs / 86400000
  readonly property int limitDays: CalendarStore.settings.flakeNagDays
  readonly property bool overdue: known && ageDays > limitDays
  readonly property real fraction: known ? Math.min(1, ageDays / limitDays) : 0

  readonly property string ageText: {
    if (!known)
      return "UNKNOWN";
    const d = Math.floor(ageMs / 86400000);
    const h = Math.floor(ageMs / 3600000) % 24;
    const m = Math.floor(ageMs / 60000) % 60;
    return d > 0 ? d + (d === 1 ? " DAY " : " DAYS ") + h + " HR" : h + " HR " + m + " MIN";
  }

  readonly property string whenText: {
    if (!known)
      return "flake.lock not found";
    const local = lockMs + Clock.offsetSec * 1000;
    return "flake.lock changed " + Cal.keyOf(Math.floor(local / 86400000)) + " " + Cal.clockText(Math.floor(local / 60000) % 1440);
  }

  function start() {
    refresh();
  }

  function refresh() {
    if (!statProc.running)
      statProc.running = true;
  }

  function tryNag() {
    if (nagDone || !checked || !CalendarStore.loaded)
      return;
    nagDone = true;
    if (CalendarStore.settings.flakeNag && overdue)
      nagDelay.start();
  }

  // the TEST button: the same message as the login reminder, shown even when notifications are silent
  function testNow() {
    NotifStore.preview("NixOS", "system-software-update", "Flake inputs are " + Math.floor(ageDays) + " days old", "Run nix flake update in ~/nixos-config, then rebuild.");
  }

  function notifyNow() {
    Sounds.play("urgent");
    const d = Math.floor(ageDays);
    Quickshell.execDetached([Tools.notifySend, "--app-name=NixOS", "--icon=system-software-update", "--", "Flake inputs are " + d + " days old", "Run nix flake update in ~/nixos-config, then rebuild."]);
  }

  Process {
    id: statProc
    command: [Tools.stat, "-c", "%Y", root.lockPath]
    stdout: StdioCollector {
      onStreamFinished: {
        const s = parseInt(text.trim());
        root.lockMs = isNaN(s) ? 0 : s * 1000;
        root.checked = true;
        root.tryNag();
      }
    }
  }

  // once per login: the marker lives in the runtime dir, which is cleared at logout
  Process {
    id: markerProc
    command: ["sh", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/quickshell-flake-nag"; if [ -e "$f" ]; then echo SKIP; else : > "$f"; echo GO; fi']
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "GO")
          root.notifyNow();
      }
    }
  }

  // give the notification server a moment to come up
  Timer {
    id: nagDelay
    interval: 6000
    onTriggered: markerProc.running = true
  }

  Timer {
    interval: 1800000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Connections {
    target: CalendarStore
    function onLoadedChanged() {
      root.tryNag();
    }
  }
}
