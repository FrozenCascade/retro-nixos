pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The playlist player: mpv without a window, controlled over its socket (home/frozen/studio.nix).
// mpv keeps the playlist itself; this file adds to it, sends commands and mirrors it for LibraryTab.
// mpv loads an MPRIS script, so while it plays it also shows up in the bar and in the PLAYER tab, and its
// sound is listed under APPLICATIONS in the Audio window like any other app.
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property string musicDir: (Quickshell.env("HOME") || "") + "/Music"
  readonly property var extensions: ["mp3", "flac", "ogg", "opus", "m4a", "wav", "aac", "wma"]

  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/studio"
  readonly property string socketPath: runtimeDir + "/mpv.sock"
  readonly property string queueFile: runtimeDir + "/queue.m3u"

  property bool wanted: false            // the player should be running
  property var playlist: []              // from mpv: [{ filename, title, current, playing }]
  property bool repeat: false
  property string note: ""
  property var folders: []               // folders inside musicDir, for quick buttons

  readonly property bool alive: player.running
  readonly property bool connected: sock.connected
  readonly property int currentIndex: playlist.findIndex(e => e.current)

  function nameOf(entry) {
    if (entry.title)
      return entry.title;
    return String(entry.filename).split("/").pop().replace(/\.[^.]+$/, "");
  }

  // ---- the player process and its socket ----
  Process {
    id: player
    running: root.wanted
    command: [Tools.studioPlayer]
    onExited: {
      root.playlist = [];
      root.wanted = false;
      sock.connected = false;
    }
  }

  // the socket appears a moment after mpv starts, so keep trying
  Timer {
    interval: 400
    repeat: true
    running: root.wanted && player.running && !sock.connected
    onTriggered: sock.connected = true
  }

  Socket {
    id: sock
    path: root.socketPath

    parser: SplitParser {
      onRead: line => root.handle(line)
    }

    onConnectedChanged: {
      if (!connected)
        return;
      root.send(["observe_property", 1, "playlist"]);
      root.send(["observe_property", 2, "loop-playlist"]);
    }
  }

  function send(command) {
    if (!sock.connected)
      return;
    sock.write(JSON.stringify({ command: command }) + "\n");
    sock.flush();
  }

  function handle(line) {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch (e) {
      return;
    }
    if (msg.event !== "property-change")
      return;
    if (msg.name === "playlist")
      playlist = msg.data || [];
    else if (msg.name === "loop-playlist")
      repeat = msg.data === "inf" || msg.data === "yes" || msg.data === true;
  }

  // ---- adding music ----
  // a folder (every song under it) or a single file
  function add(path) {
    const p = String(path).trim().replace(/^~/, Quickshell.env("HOME") || "");
    if (p === "")
      return;
    note = "";
    wanted = true;
    scan.path = p;
    scan.running = true;
  }

  Process {
    id: scan
    property string path: ""
    command: ["sh", "-c",
      'mkdir -p "$(dirname "$2")"; if [ -d "$1" ]; then find -L "$1" -type f \\( ' + root.extensions.map(e => '-iname "*.' + e + '"').join(" -o ") + ' \\) | sort > "$2"; elif [ -f "$1" ]; then printf "%s\\n" "$1" > "$2"; else : > "$2"; fi; wc -l < "$2"',
      "sh", path, root.queueFile]
    stdout: StdioCollector {
      onStreamFinished: {
        const n = parseInt(text.trim());
        if (!n) {
          root.note = "NO SONGS THERE";
          return;
        }
        root.note = "ADDED " + n + (n === 1 ? " SONG" : " SONGS");
        loadTimer.restart();
      }
    }
  }

  // give a freshly started mpv time to open its socket before the list is sent
  Timer {
    id: loadTimer
    interval: 600
    repeat: true
    onTriggered: {
      if (!root.connected)
        return;
      running = false;
      root.send(["loadlist", root.queueFile, "append-play"]);
    }
  }

  // ---- controls ----
  function playIndex(i) {
    send(["playlist-play-index", i]);
  }

  function removeIndex(i) {
    send(["playlist-remove", i]);
  }

  function shuffle() {
    send(["playlist-shuffle"]);
  }

  function toggleRepeat() {
    send(["set_property", "loop-playlist", repeat ? "no" : "inf"]);
  }

  function clear() {
    send(["stop"]);
    send(["playlist-clear"]);
  }

  function quit() {
    send(["quit"]);
    wanted = false;
  }

  // ---- folders inside the music folder, for the quick buttons ----
  function refreshFolders() {
    if (!folderScan.running)
      folderScan.running = true;
  }

  Process {
    id: folderScan
    command: ["find", "-L", root.musicDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d"]
    stdout: StdioCollector {
      onStreamFinished: root.folders = text.split("\n").filter(l => l !== "").sort()
    }
  }
}
