pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

// Audio through PipeWire: the default speakers and microphone, every device, every app that is playing
// or recording (kept on screen for a few seconds after it stops), and a mic test.
Singleton {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  // reading volume, mute and properties needs the nodes to be bound
  PwObjectTracker {
    objects: Pipewire.nodes.values
  }

  // Outputs on a monitor cable (HDMI, DisplayPort) are listed after the others. Change the pattern to
  // move other kinds of device, e.g. /bluez/i to push Bluetooth down too.
  readonly property var displayOutput: /hdmi|display ?port/i

  function lastIfDisplay(list) {
    const isDisplay = n => displayOutput.test((n.name || "") + " " + (n.description || "") + " " + (n.nickname || ""));
    return list.filter(n => !isDisplay(n)).concat(list.filter(isDisplay));
  }

  readonly property var sinks: lastIfDisplay(Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream))
  readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && n.properties && n.properties["media.class"] === "Audio/Source")
  // Programs that play sounds for the shell itself; they are left out of the Applications list.
  // Matched against the stream's application name or program name (lower case). Add more here.
  readonly property var hiddenStreams: ["pw-play", "pw-cat"]

  function shownStream(n) {
    const p = n.properties || {};
    const names = [p["application.name"], p["application.process.binary"]].map(s => String(s || "").toLowerCase());
    return !names.some(s => hiddenStreams.indexOf(s) !== -1);
  }

  readonly property var playNodes: Pipewire.nodes.values.filter(n => n.audio && n.properties && n.properties["media.class"] === "Stream/Output/Audio" && shownStream(n))
  readonly property var recNodes: Pipewire.nodes.values.filter(n => n.audio && n.properties && n.properties["media.class"] === "Stream/Input/Audio")

  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  readonly property real micVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool micMuted: source && source.audio ? source.audio.muted : false
  readonly property bool micInUse: recNodes.length > 0       // some app has the microphone open

  // the bar icon follows the output volume
  readonly property string icon: muted || volume < 0.005 ? Glyphs.volOff : (volume < 0.34 ? Glyphs.volLow : (volume < 0.67 ? Glyphs.volMid : Glyphs.volHigh))

  // ---- names and icons ----
  function label(n) {
    if (!n)
      return "NONE";
    return n.nickname || n.description || n.name || "UNKNOWN";
  }

  function appLabel(n) {
    const p = n.properties || {};
    const o = Desktop.overrideAny([p["application.process.binary"], p["application.name"], p["application.icon-name"]]);
    if (o && o.name)
      return o.name;
    return p["application.name"] || p["media.name"] || n.nickname || n.name || "APP";
  }

  // icon names come from the device or app itself when it gives one
  function deviceIcon(n) {
    const p = (n && n.properties) || {};
    return p["device.icon-name"] || p["device.icon_name"] || (n && n.isSink ? "audio-speakers" : "audio-input-microphone");
  }

  function appIcon(n) {
    const p = n.properties || {};
    const o = Desktop.overrideAny([p["application.process.binary"], p["application.name"], p["application.icon-name"]]);
    if (o && o.icon)
      return o.icon;
    return p["application.icon-name"] || p["application.icon_name"] || (p["application.process.binary"] || "").toLowerCase() || (p["application.name"] || "").toLowerCase() || "audio-x-generic";
  }

  function iconUrl(name, fallback) {
    return Quickshell.iconPath(name, fallback || "audio-card");
  }

  // ---- volume, mute and defaults ----
  // MAX: while it is on for a device or app, its volume can go up to 150%
  property var boosted: ({})

  function maxOf(id) {
    return boosted[id] ? 1.5 : 1.0;
  }

  function toggleBoost(id, audio) {
    const b = Object.assign({}, boosted);
    if (b[id]) {
      delete b[id];
      if (audio && audio.volume > 1.0)
        audio.volume = 1.0;
    } else {
      b[id] = true;
    }
    boosted = b;
  }

  function setVolume(v) {
    if (sink && sink.audio)
      sink.audio.volume = Math.max(0, Math.min(maxOf(sink.id), v));
  }

  // the bar button's scroll wheel: raise or lower the output by `delta`, and unmute when going up
  function nudge(delta) {
    if (!sink || !sink.audio)
      return;
    if (sink.audio.muted && delta > 0)
      sink.audio.muted = false;
    setVolume(Math.round((volume + delta) * 100) / 100);
    Sounds.volumeTick();
  }

  function setMuted(m) {
    if (sink && sink.audio)
      sink.audio.muted = m;
  }

  function setMicVolume(v) {
    if (source && source.audio)
      source.audio.volume = Math.max(0, Math.min(maxOf(source.id), v));
  }

  function setMicMuted(m) {
    if (source && source.audio)
      source.audio.muted = m;
  }

  signal micPoked          // the bar's mic key changed the level or the mute: MicOsd shows it

  // the mic key's scroll wheel: raise or lower the mic by `delta`, and unmute when going up
  function nudgeMic(delta) {
    if (!source || !source.audio)
      return;
    if (source.audio.muted && delta > 0)
      source.audio.muted = false;
    const level = Math.round((micVolume + delta) * 100) / 100;
    setMicVolume(level);
    micPoked();
    if (!micMuted)
      Sounds.micTick(Math.max(0, Math.min(1.5, level)));
  }

  // the mic key's middle click
  function toggleMicMuted() {
    setMicMuted(!micMuted);
    micPoked();
  }

  function isDefault(n) {
    return !!n && ((sink && n.id === sink.id) || (source && n.id === source.id));
  }

  function makeDefault(n) {
    if (n.isSink)
      Pipewire.preferredDefaultAudioSink = n;
    else
      Pipewire.preferredDefaultAudioSource = n;
  }

  // ---- app lists that hold on to a stream for a few seconds after it ends ----
  readonly property int keepMs: 5000
  property var playRows: []     // { key, node (null once it ended), name, icon, vol, muted, goneAt }
  property var recRows: []

  function merge(prev, nodes) {
    const now = Date.now();
    const seen = {};
    const next = [];
    for (const n of nodes) {
      seen[n.id] = true;
      next.push({ key: n.id, node: n, name: appLabel(n), icon: appIcon(n), vol: n.audio.volume, muted: n.audio.muted, goneAt: 0 });
    }
    for (const r of prev) {
      if (seen[r.key])
        continue;
      const goneAt = r.goneAt || now;
      if (now - goneAt < keepMs)
        next.push({ key: r.key, node: null, name: r.name, icon: r.icon, vol: r.vol, muted: r.muted, goneAt: goneAt });
    }
    return next;
  }

  function sameRows(a, b) {
    return a.length === b.length && a.every((r, i) => r.key === b[i].key && (r.goneAt > 0) === (b[i].goneAt > 0));
  }

  function sync() {
    const p = merge(playRows, playNodes);
    if (!sameRows(p, playRows))
      playRows = p;
    const r = merge(recRows, recNodes);
    if (!sameRows(r, recRows))
      recRows = r;
  }

  onPlayNodesChanged: sync()
  onRecNodesChanged: sync()

  Timer {
    interval: 1000
    repeat: true
    running: root.playRows.some(r => r.goneAt > 0) || root.recRows.some(r => r.goneAt > 0)
    onTriggered: root.sync()
  }

  // ---- mic test: record four seconds, then play it back ----
  property string testState: "idle"      // idle | recording | playing

  function micTest() {
    if (testState !== "idle")
      return;
    testState = "recording";
    recordProc.running = true;
  }

  Process {
    id: recordProc
    command: ["timeout", "-s", "INT", "4", "pw-record", "/tmp/qs-mic-test.wav"]
    onExited: {
      root.testState = "playing";
      playProc.running = true;
    }
  }

  Process {
    id: playProc
    command: ["pw-play", "/tmp/qs-mic-test.wav"]
    onExited: root.testState = "idle"
  }
}
