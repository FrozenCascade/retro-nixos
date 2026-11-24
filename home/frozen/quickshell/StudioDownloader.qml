pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components.shared

// yt-dlp behind the DOWNLOAD tab: the options you pick there become yt-dlp arguments (buildArgs),
// studio-download runs it (studio.nix), and its progress lines come back here.
// Links also come from  qs ipc call studio download <link>
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property string videoDir: Quickshell.env("HOME") + "/Videos/Downloads"
  readonly property string audioDir: Quickshell.env("HOME") + "/Music/Downloads"
  readonly property string fileName: "%(title).150B [%(id)s].%(ext)s"       // yt-dlp output template
  readonly property var heightChoices: [0, 2160, 1440, 1080, 720, 480]      // 0 = the best there is
  readonly property var containerChoices: ["mp4", "mkv", "webm"]
  readonly property var audioChoices: ["mp3", "m4a", "opus", "flac"]
  readonly property var speedChoices: [0, 1, 2, 5, 10]                       // MB/s; 0 = no limit
  readonly property var browserChoices: ["", "firefox", "chromium", "brave"] // where to take cookies from
  readonly property int historySize: 8

  // ---- the options (kept between runs) ----
  property string mode: "video"          // "video" or "audio"
  property int maxHeight: 1080
  property string container: "mp4"
  property string audioFormat: "mp3"
  property bool playlist: false          // a link that is part of a playlist: the whole playlist
  property bool subtitles: false
  property bool thumbnail: true          // cover picture inside the file
  property bool metadata: true           // title, artist, ... inside the file
  property bool sponsorblock: false      // cut sponsor and self-promotion parts out
  property string cookies: ""            // browser name, for videos that need a login
  property int speed: 0

  // ---- what is happening ----
  property bool busy: false
  property real percent: -1              // -1 until yt-dlp reports one
  property string speedText: ""
  property string etaText: ""
  property string title: ""
  property string note: ""
  property var history: []               // newest first: [{ title, file, ok }]
  property bool stopped: false

  readonly property string folder: mode === "audio" ? audioDir : videoDir

  signal pasted(string text)

  function heightName(h) {
    return h === 0 ? "BEST" : h + "P";
  }

  // the yt-dlp arguments for the current options
  function buildArgs() {
    const a = [
      "--newline", "--no-simulate", "--no-quiet", "--ignore-errors",
      "--progress-template", "download:STUDIO|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
      "--print", "before_dl:TITLE|%(title)s",
      "--print", "after_move:FILE|%(filepath)s",
      "-P", folder, "-o", fileName,
      playlist ? "--yes-playlist" : "--no-playlist"
    ];

    if (mode === "audio") {
      a.push("-x", "--audio-format", audioFormat, "--audio-quality", "0");
    } else {
      const h = maxHeight > 0 ? "[height<=" + maxHeight + "]" : "";
      a.push("-f", "bv*" + h + "+ba/b" + h + "/b", "--merge-output-format", container);
      if (subtitles)
        a.push("--write-subs", "--write-auto-subs", "--sub-langs", "en.*", "--embed-subs");
    }

    if (thumbnail)
      a.push("--embed-thumbnail");
    if (metadata)
      a.push("--embed-metadata");
    if (sponsorblock)
      a.push("--sponsorblock-remove", "sponsor,selfpromo");
    if (cookies !== "")
      a.push("--cookies-from-browser", cookies);
    if (speed > 0)
      a.push("-r", speed + "M");
    return a;
  }

  // ---- start and stop ----
  function start(text) {
    if (busy)
      return;
    const urls = String(text).trim().split(/\s+/).filter(u => /^https?:\/\//.test(u));
    if (urls.length === 0) {
      note = "PASTE A LINK FIRST";
      return;
    }
    note = "";
    title = "";
    percent = -1;
    stopped = false;
    busy = true;
    proc.command = [Tools.studioDownload].concat(buildArgs(), urls);
    proc.running = true;
  }

  function stop() {
    if (proc.running) {
      stopped = true;
      proc.signal(2);
    }
  }

  function openFolder() {
    Quickshell.execDetached([Tools.studioDownload, "open", folder]);
  }

  function paste() {
    pasteProc.running = true;
  }

  function remember(entry) {
    history = [entry].concat(history).slice(0, historySize);
  }

  Process {
    id: proc

    stdout: SplitParser {
      onRead: line => {
        const p = line.split("|");
        if (p[0] === "STUDIO") {
          const n = parseFloat(p[1]);
          root.percent = isNaN(n) ? -1 : n;
          root.speedText = (p[2] || "").trim();
          root.etaText = (p[3] || "").trim();
        } else if (p[0] === "TITLE") {
          root.title = p.slice(1).join("|");
          root.percent = 0;
        } else if (p[0] === "FILE") {
          root.remember({ title: root.title, file: p.slice(1).join("|"), ok: true });
        }
      }
    }

    stderr: StdioCollector {
      id: err
    }

    onExited: code => {
      root.busy = false;
      root.percent = -1;
      if (root.stopped) {
        root.note = "STOPPED";
      } else if (code === 0) {
        root.note = "DONE";
        Quickshell.execDetached([Tools.studioDownload, "notify", "Download finished", root.title]);
        StudioState.reveal("download");
      } else {
        const why = err.text.trim().split("\n").pop();
        root.note = "FAILED: " + (why !== "" ? why : "EXIT " + code);
        root.remember({ title: root.title !== "" ? root.title : "A DOWNLOAD", file: "", ok: false });
        console.warn("studio-download exited with " + code + ": " + err.text);
      }
    }
  }

  Process {
    id: pasteProc
    command: [Tools.studioDownload, "paste"]
    stdout: StdioCollector {
      onStreamFinished: root.pasted(text.trim())
    }
  }

  // ---- remembered between runs ----
  StatePrefs {
    id: prefs
    file: "download.json"
    data: ({
      mode: root.mode, maxHeight: root.maxHeight, container: root.container, audioFormat: root.audioFormat,
      playlist: root.playlist, subtitles: root.subtitles, thumbnail: root.thumbnail, metadata: root.metadata,
      sponsorblock: root.sponsorblock, cookies: root.cookies, speed: root.speed
    })
    onLoaded: saved => {
      if (saved.mode === "video" || saved.mode === "audio")
        root.mode = saved.mode;
      if (root.heightChoices.indexOf(saved.maxHeight) !== -1)
        root.maxHeight = saved.maxHeight;
      if (root.containerChoices.indexOf(saved.container) !== -1)
        root.container = saved.container;
      if (root.audioChoices.indexOf(saved.audioFormat) !== -1)
        root.audioFormat = saved.audioFormat;
      if (root.speedChoices.indexOf(saved.speed) !== -1)
        root.speed = saved.speed;
      if (root.browserChoices.indexOf(saved.cookies) !== -1)
        root.cookies = saved.cookies;
      for (const k of ["playlist", "subtitles", "thumbnail", "metadata", "sponsorblock"])
        if (typeof saved[k] === "boolean")
          root[k] = saved[k];
    }
  }

  // one place that changes an option and keeps it
  function set(name, value) {
    root[name] = value;
    prefs.save();
  }
}
