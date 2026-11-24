pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Sound effects from a freedesktop sound theme (https://specifications.freedesktop.org/sound-naming-spec).
// Install the theme with Nix (see the flake input "cobalt") or put it in ~/.local/share/sounds/<theme>/ .
// Every data folder is searched on start, and an effect plays
// only if the theme has a file for it, so a theme missing some sounds is fine.
Singleton {
  id: root

  property bool enabled: true
  property real volume: 0.7
  readonly property string theme: "cobalt"
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string dir: home + "/.local/share/sounds/" + theme

  property var files: ({})              // sound name -> file path, from the scan
  property var last: ({})

  // what each event is called in the theme; the first name the theme has is used
  readonly property var names: ({
    volume: ["audio-volume-change"],
    notify: ["message-new-instant", "message"],
    urgent: ["dialog-warning", "dialog-error"],
    alarm: ["alarm-clock-elapsed", "complete"],
    lock: ["service-logout", "desktop-logout"],
    unlock: ["service-login", "desktop-login"],
    click: ["button-pressed"],
    screenshot: ["screen-capture", "camera-shutter"],
    mic: ["bell", "dialog-information", "message", "complete", "audio-volume-change"]
  })

  // `gain` (0..1.5) scales the effect, for sounds that stand for a level
  function play(event, gain) {
    if (!enabled)
      return;
    const now = Date.now();
    if (now - (last[event] || 0) < 150)
      return;
    for (const n of (names[event] || [event])) {
      if (files[n]) {
        last[event] = now;
        Quickshell.execDetached(["pw-play", "--volume", String(volume * (gain === undefined ? 1 : gain)), files[n]]);
        return;
      }
    }
  }

  // the volume sound plays once the change settles, so dragging a slider does not machine-gun it
  function volumeTick() {
    tick.restart();
  }

  Timer {
    id: tick
    interval: 200
    onTriggered: root.play("volume")
  }

  // the mic key's wheel: a sound at the new mic level, once the change settles
  property real micLevel: 1

  function micTick(level) {
    micLevel = level;
    micWait.restart();
  }

  Timer {
    id: micWait
    interval: 200
    onTriggered: root.play("mic", root.micLevel)
  }

  function toggle() {
    enabled = !enabled;
    save();
  }

  function save() {
    prefs.setText(JSON.stringify({ enabled: enabled, volume: volume }));
  }

  FileView {
    id: prefs
    path: Quickshell.statePath("sounds.json")
    onLoaded: {
      try {
        const d = JSON.parse(prefs.text());
        root.enabled = d.enabled !== false;
        root.volume = d.volume > 0 ? d.volume : 0.7;
      } catch (e) {}
    }
  }

  Process {
    running: true
    command: ["sh", "-c", 'for d in $(echo "$HOME/.local/share:$XDG_DATA_DIRS" | tr ":" " "); do find -L "$d/sounds/$1" -maxdepth 3 -type f \\( -name "*.oga" -o -name "*.ogg" -o -name "*.wav" -o -name "*.opus" -o -name "*.flac" \\) 2>/dev/null; done', "sh", root.theme]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        for (const p of text.split("\n")) {
          if (p === "")
            continue;
          const base = p.split("/").pop().replace(/\.[^.]+$/, "");
          if (!m[base])      // the first folder found wins (your own ~/.local/share, then the system)
            m[base] = p;
        }
        root.files = m;
      }
    }
  }
}
