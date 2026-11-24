pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components.shared

// Screen recording with gpu-screen-recorder, through the studio-record script (home/frozen/studio.nix).
// A recording is kept in ~/.cache/studio until you SAVE it (the tab, or the button on the notification).
// Start and stop from the Studio window, from the middle click on the bar's song key, or
//   qs ipc call studio record toggle
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property var fpsChoices: [15, 24, 30, 48, 60, 90, 120, 144]     // the high ones need a fast encoder
  readonly property var limitChoices: [0, 5, 15, 30, 60]          // minutes; 0 = until you stop it
  readonly property var delayChoices: [0, 3, 5, 10]               // seconds, counted after the area is chosen
  readonly property string defaultOutput: "default_output"        // gpu-screen-recorder's names for the
  readonly property string defaultInput: "default_input"          // current speakers and microphone

  // ---- what to record ----
  property string target: "region"      // one of RegionPicker.recordAreas: region, window, a monitor, last
  property int fps: 60
  property int limitMinutes: 0
  property int delay: 0                 // seconds to wait before the recording starts
  property var audio: ["default_output"]       // device names, each recorded into the one audio track

  // ---- state ----
  property bool starting: false         // chosen, waiting for the area or for the recorder to begin
  property bool recording: false
  property real startedAt: 0
  property int elapsed: 0               // seconds
  property bool haveFile: false         // a finished recording waits to be saved or discarded
  property string note: ""
  property string savedPath: ""        // where the last recording was saved, so it can still be previewed

  readonly property bool canPreview: haveFile || savedPath !== ""

  readonly property bool busy: starting || recording

  property bool obsRecording: false     // OBS Studio is recording (read from its WebSocket server)

  readonly property string elapsedText: {
    const m = Math.floor(elapsed / 60);
    const s = elapsed % 60;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  // ---- audio devices (from PipeWire, through AudioState) ----
  // what you can pick: the two defaults, then every output (its monitor, so what you hear) and every input
  readonly property var audioChoices: {
    const list = [
      { id: defaultOutput, name: "DEFAULT OUTPUT (WHAT YOU HEAR)" },
      { id: defaultInput, name: "DEFAULT MICROPHONE" }
    ];
    for (const n of AudioState.sinks)
      list.push({ id: n.name + ".monitor", name: "OUTPUT: " + AudioState.label(n).toUpperCase() });
    for (const n of AudioState.sources)
      list.push({ id: n.name, name: "INPUT: " + AudioState.label(n).toUpperCase() });
    return list;
  }

  function hasAudio(id) {
    return audio.indexOf(id) !== -1;
  }

  function toggleAudio(id) {
    audio = hasAudio(id) ? audio.filter(a => a !== id) : audio.concat([id]);
    prefs.save();
  }

  function setTarget(t) {
    target = t;
    prefs.save();
  }

  function setFps(f) {
    fps = f;
    prefs.save();
  }

  function setDelay(s) {
    delay = s;
    prefs.save();
  }

  function setLimit(m) {
    limitMinutes = m;
    prefs.save();
  }

  // ---- start and stop ----
  function start() {
    if (busy)
      return;
    note = "";
    starting = true;
    StudioState.aboutToCapture();        // popups close first, so they are not in the picture
    begin.restart();
  }

  function stop() {
    if (proc.running)
      proc.signal(2);                    // SIGINT: gpu-screen-recorder finishes the file
    else if (countdown.running) {
      countdown.stop();                  // the start delay is running
      left = 0;
      starting = false;
      note = "CANCELLED";
    } else if (starting)
      RegionPicker.cancel();             // still choosing the area
  }

  function toggle() {
    busy ? stop() : start();
  }

  // the area is chosen first (RegionPicker), then studio-record starts
  function launch(area, why) {
    if (!area) {
      starting = false;
      note = why || "";
      return;
    }
    if (delay > 0) {
      waiting = area;
      left = delay;
      note = "STARTING IN " + left;
      countdown.start();
    } else {
      run(area);
    }
  }

  function run(area) {
    proc.command = [Tools.studioRecord, "start", area.mode, String(fps), audio.join("|"), area.geom];
    proc.running = true;
  }

  // the start delay: a second at a time, the note says how long is left
  property var waiting: null
  property int left: 0

  Timer {
    id: countdown
    interval: 1000
    repeat: true
    onTriggered: {
      root.left--;
      if (root.left > 0) {
        root.note = "STARTING IN " + root.left;
        return;
      }
      countdown.stop();
      root.note = "";
      root.run(root.waiting);
    }
  }

  Timer {
    id: begin
    interval: 250
    onTriggered: RegionPicker.resolve(root.target, "RECORD", (area, why) => root.launch(area, why))
  }

  Process {
    id: proc

    // the script prints "recording" once the recorder is going
    stdout: SplitParser {
      onRead: line => {
        if (line.trim() === "recording") {
          root.startedAt = Date.now();
          root.elapsed = 0;
          root.starting = false;
          root.recording = true;
        }
      }
    }

    stderr: StdioCollector {
      id: err
    }

    onExited: code => {
      const was = root.recording;
      root.starting = false;
      root.recording = false;
      if (was) {
        root.haveFile = true;
        root.note = "RECORDED " + root.elapsedText + ". NOT SAVED YET";
        Quickshell.execDetached([Tools.studioRecord, "finished"]);
        StudioState.reveal("record");
      } else if (code !== 0 && code !== 1) {
        const why = err.text.trim().split("\n").pop();
        root.note = "FAILED TO START" + (why !== "" ? ": " + why.toUpperCase() : "");
        console.warn("studio-record exited with " + code + ": " + err.text);
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.recording
    onTriggered: {
      root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000);
      if (root.limitMinutes > 0 && root.elapsed >= root.limitMinutes * 60)
        root.stop();
    }
  }

  // ---- OBS Studio ----
  // The bar's song key shows the recording dot for OBS too, and its middle click ends OBS's recording
  // (otherwise it toggles this recorder). OBS needs its WebSocket server on: see home/frozen/studio/obs-record.py.
  function middleClick() {
    if (obsRecording)
      Quickshell.execDetached([Tools.studioObs, "stop"]);
    else
      toggle();
  }

  Process {
    running: true
    command: [Tools.studioObs, "watch"]
    stdout: SplitParser {
      onRead: line => root.obsRecording = line.trim() === "recording"
    }
    onExited: root.obsRecording = false
  }

  // ---- what to do with the finished recording ----
  function save() {
    saveProc.command = [Tools.studioRecord, "save"];
    saveProc.running = true;
  }

  // asks where to put the recording (studio-record saveas)
  function saveAs() {
    saveProc.command = [Tools.studioRecord, "saveas"];
    saveProc.running = true;
  }

  // opens the recording in mpv: sound, seeking, pause (the file waiting to be saved, else the saved one)
  function preview() {
    const cmd = [Tools.studioRecord, "preview"];
    if (!haveFile)
      cmd.push(savedPath);
    Quickshell.execDetached(cmd);
  }

  function discard() {
    Quickshell.execDetached([Tools.studioRecord, "discard"]);
    haveFile = false;
    savedPath = "";
    note = "DISCARDED";
  }

  Process {
    id: saveProc
    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim();
        if (path !== "") {
          root.haveFile = false;
          root.savedPath = path;
          root.note = "SAVED TO " + path.replace(/^.*\/Videos\//, "~/Videos/");
        }
      }
    }
  }

  // ---- remembered between runs ----
  StatePrefs {
    id: prefs
    file: "recorder.json"
    data: ({ target: root.target, fps: root.fps, limitMinutes: root.limitMinutes, delay: root.delay, audio: root.audio })
    onLoaded: saved => {
      if (saved.target && saved.target !== "screen")      // ALL MONITORS was removed
        root.target = saved.target;
      if (root.fpsChoices.indexOf(saved.fps) !== -1)
        root.fps = saved.fps;
      if (root.limitChoices.indexOf(saved.limitMinutes) !== -1)
        root.limitMinutes = saved.limitMinutes;
      if (root.delayChoices.indexOf(saved.delay) !== -1)
        root.delay = saved.delay;
      if (Array.isArray(saved.audio))
        root.audio = saved.audio;
    }
  }
}
