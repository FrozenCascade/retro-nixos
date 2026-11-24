pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/calendar.js" as Cal

// What the Session window shows and controls: facts about this system, your user icon, stay awake,
// which status apps you hid, and the power actions.
Singleton {
  id: root

  readonly property string user: Quickshell.env("USER") || ""
  readonly property string home: Quickshell.env("HOME") || ""
  property string host: ""
  property string uptime: ""
  property bool stayAwake: false

  // Holding an idle inhibitor stops hypridle (and any idle timer) from sleeping the machine. It is
  // released when this turns off, or when Quickshell ends.
  Process {
    running: root.stayAwake
    command: ["systemd-inhibit", "--what=idle", "--who=Quickshell", "--why=Stay awake is on", "--mode=block", "sleep", "infinity"]
  }

  Process {
    running: true
    command: ["hostname"]
    stdout: StdioCollector {
      onStreamFinished: root.host = text.trim()
    }
  }

  Process {
    id: uptimeProc
    command: ["uptime", "-p"]
    stdout: StdioCollector {
      onStreamFinished: root.uptime = text.trim().replace(/^up /, "")
    }
  }

  // ---- about this system ----
  property var facts: ({})
  property real factsAt: 0

  readonly property string factsScript: [
    '. /etc/os-release 2>/dev/null',
    'echo "os=$NAME"',
    'echo "version=$VERSION"',
    'echo "gen=$(readlink /nix/var/nix/profiles/system 2>/dev/null | sed "s/[^0-9]//g")"',
    'echo "kernel=$(uname -r)"',
    'echo "hypr=$(hyprctl version 2>/dev/null | head -1)"',
    'echo "qs=$(quickshell --version 2>/dev/null | head -1)"',
    'ts=$(loginctl show-session "$XDG_SESSION_ID" -p Timestamp --value 2>/dev/null)',
    'now=$(date +%s); then=$now; [ -n "$ts" ] && then=$(date -d "$ts" +%s 2>/dev/null || echo $now)',
    'echo "session=$((now - then))"',
    'echo "cpu=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed "s/^ *//")"',
    'echo "gpu=$(lspci 2>/dev/null | grep -iE "vga|3d|display" | head -1 | sed "s/.*: //; s/ (rev.*//")"',
    'echo "mem=$(free -b | sed -n 2p)"',
    'echo "disk=$(df -B1 / | sed -n 2p)"',
    'echo "nix=$(nix --version 2>/dev/null)"'
  ].join("\n")

  function refreshFacts() {
    if (!factsProc.running)
      factsProc.running = true;
    uptimeProc.running = true;
  }

  Process {
    id: factsProc
    command: ["sh", "-c", root.factsScript]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        for (const line of text.split("\n")) {
          const i = line.indexOf("=");
          if (i > 0)
            m[line.slice(0, i)] = line.slice(i + 1).trim();
        }
        root.facts = m;
        root.factsAt = Clock.nowMs;
      }
    }
  }

  function gib(bytes) {
    return (bytes / 1073741824).toFixed(1);
  }

  readonly property string hyprVersion: (/Hyprland\s+(\S+)/.exec(facts.hypr || "") || [])[1] || ""
  readonly property string qsVersion: (/quickshell\s+([0-9][^\s,]*)/i.exec(facts.qs || "") || [])[1] || ""

  // the rows of the "about this system" list
  readonly property var infoRows: {
    const f = facts;
    const mem = (f.mem || "").split(/\s+/);
    const disk = (f.disk || "").split(/\s+/);
    const secs = f.session ? +f.session + (Clock.nowMs - factsAt) / 1000 : 0;
    const screens = Quickshell.screens.map(s => s.name + " " + s.width + "x" + s.height).join(", ");
    const rows = [
      { k: "OS", v: f.os || "" },
      { k: "VERSION", v: f.version || "" },
      { k: "GENERATION", v: f.gen ? "#" + f.gen : "" },
      { k: "KERNEL", v: f.kernel || "" },
      { k: "HYPRLAND", v: hyprVersion },
      { k: "QUICKSHELL", v: qsVersion },
      { k: "SESSION", v: secs > 60 ? Cal.lengthText(secs / 60).toUpperCase() : "" },
      { k: "UPTIME", v: uptime.toUpperCase() },
      { k: "CPU", v: f.cpu || "" },
      { k: "GPU", v: f.gpu || "" },
      { k: "MEMORY", v: mem.length > 2 ? gib(+mem[2]) + " / " + gib(+mem[1]) + " GIB" : "" },
      { k: "DISK", v: disk.length > 4 ? gib(+disk[2]) + " / " + gib(+disk[1]) + " GIB (" + disk[4] + ")" : "" },
      { k: "DISPLAYS", v: screens },
      { k: "NIX", v: (f.nix || "").replace(/^nix \(Nix\) /, "") },
      { k: "FONT", v: Theme.fontMono }
    ];
    return rows.filter(r => r.v !== "");
  }

  // ---- your user icon (~/.face is what KDE and SDDM read) ----
  property string avatarUrl: ""
  property var pictures: []

  function loadAvatar() {
    avatarUrl = "";
    Qt.callLater(function () {
      root.avatarUrl = "file://" + root.home + "/.face";
    });
  }

  function scanPictures() {
    pictureProc.running = true;
  }

  function setAvatar(path) {
    copyProc.command = ["sh", "-c", 'cp -f -- "$1" "$HOME/.face" && cp -f -- "$HOME/.face" "$HOME/.face.icon"', "sh", path];
    copyProc.running = true;
  }

  Process {
    id: pictureProc
    command: ["sh", "-c", 'find "$HOME/Pictures/Wallpapers" -maxdepth 2 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) 2>/dev/null | head -30']
    stdout: StdioCollector {
      onStreamFinished: root.pictures = text.split("\n").filter(s => s !== "")
    }
  }

  Process {
    id: copyProc
    onExited: root.loadAvatar()
  }

  // ---- status apps you chose to hide (kept in session.json) ----
  property var hiddenTray: []

  function isHidden(id) {
    return hiddenTray.indexOf(id) !== -1;
  }

  function setHidden(id, hide) {
    const rest = hiddenTray.filter(x => x !== id);
    hiddenTray = hide ? rest.concat([id]) : rest;
    trayFile.setText(JSON.stringify({ hiddenTray: hiddenTray }));
  }

  FileView {
    id: trayFile
    path: Quickshell.statePath("session.json")
    onLoaded: {
      try {
        root.hiddenTray = JSON.parse(trayFile.text()).hiddenTray || [];
      } catch (e) {}
    }
  }

  Component.onCompleted: {
    loadAvatar();
    refreshFacts();
  }

  // ---- power ----
  function lock() {
    LockState.locked = true;
  }

  function sleep() {
    LockState.lockAndSuspend();
  }

  function logout() {
    Quickshell.execDetached(["uwsm", "stop"]);
  }

  function restart() {
    Quickshell.execDetached(["systemctl", "reboot"]);
  }

  function shutdown() {
    Quickshell.execDetached(["systemctl", "poweroff"]);
  }
}
