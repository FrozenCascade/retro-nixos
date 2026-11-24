pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "lib/playerArt.js" as PlayerArt
import qs.components.shared

// Studio: the media player behind the bar button and the Studio window, screenshots, and the side
// mouse buttons. Recording, downloads and the playlist player have their own files
// (StudioRecorder, StudioDownloader, StudioLibrary); the IPC target "studio" below reaches all of them.
// Anything that runs a program takes its path from Tools.
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property int seekSeconds: 5              // scroll on the pause key, and the +/- buttons
  // what can be captured (REGION, WINDOW, each monitor, ALL MONITORS, LAST REGION) is RegionPicker.areas
  readonly property var shotDelays: [0, 3, 5, 10]   // seconds, counted after the area is chosen

  // what the side mouse buttons can do (chosen in the RECORD tab)
  readonly property var sideChoices: [
    { id: "none", name: "NOTHING" },
    { id: "record", name: "RECORD" },
    { id: "playpause", name: "PLAY/PAUSE" },
    { id: "shot", name: "SCREENSHOT" }
  ]

  // ================= player (Mpris) =================
  // a player with nothing loaded (an idle mpv, for one) is left out, so there is no empty source
  readonly property var players: Mpris.players.values.filter(p => p.isPlaying || (p.trackTitle || "") !== "")
  property string wanted: ""            // dbus name of the player picked by hand; "" = automatic

  // the picked player, else one that is playing, else the first
  readonly property var player: players.find(p => p.dbusName === wanted) || players.find(p => p.isPlaying) || players[0] || null

  readonly property bool playing: player ? player.isPlaying : false
  readonly property string title: player && player.trackTitle ? player.trackTitle : ""
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
  readonly property string art: (PlayerArt.urlFor(player) || ArtLookup.art)

  // the text on the bar button
  readonly property string label: {
    if (!player)
      return "STUDIO";
    if (title === "")
      return player.identity;
    return artist !== "" ? title + "  -  " + artist : title;
  }

  function togglePlay() {
    if (player && player.canTogglePlaying)
      player.togglePlaying();
  }

  function next() {
    if (player && player.canGoNext)
      player.next();
  }

  function previous() {
    if (player && player.canGoPrevious)
      player.previous();
  }

  // forward (+1) or back (-1) by seekSeconds
  function seekStep(dir) {
    if (player && player.canSeek)
      player.seek(dir * seekSeconds);
  }

  // scroll through the players: +1 next, -1 previous
  function cycle(dir) {
    const n = players.length;
    if (n < 2)
      return;
    const i = Math.max(0, players.indexOf(player));
    wanted = players[(i + dir + n) % n].dbusName;
  }

  // ---- mute the player ----
  // The player's own PipeWire stream is muted when it can be found by name; otherwise the player's
  // own volume is set to 0 (and back to what it was).
  property real volumeBeforeMute: 1

  function streamOf(p) {
    if (!p)
      return null;
    const names = [p.identity, p.desktopEntry].filter(s => s).map(s => String(s).toLowerCase());
    return AudioState.playNodes.find(n => {
      const props = n.properties || {};
      const have = [props["application.name"], props["application.process.binary"]].filter(s => s).map(s => String(s).toLowerCase());
      return have.some(h => names.some(w => h.indexOf(w) !== -1 || w.indexOf(h) !== -1));
    }) || null;
  }

  readonly property var stream: streamOf(player)
  readonly property bool muted: stream && stream.audio ? stream.audio.muted : (player && player.volumeSupported ? player.volume < 0.001 : false)

  function toggleMute() {
    if (stream && stream.audio) {
      stream.audio.muted = !stream.audio.muted;
    } else if (player && player.volumeSupported) {
      if (player.volume > 0.001) {
        volumeBeforeMute = player.volume;
        player.volume = 0;
      } else {
        player.volume = volumeBeforeMute > 0 ? volumeBeforeMute : 1;
      }
    }
  }

  // ================= screenshots =================
  property string shotMode: "region"
  property int shotDelay: 0
  property string lastShot: ""          // the file of the last capture (kept until the next one)
  property int shotCount: 0             // changes with every capture, so a preview reloads
  property string shotNote: ""          // a short line for the CAPTURE tab
  property bool shotBusy: false

  // ---- showing the result: when a capture or recording is made the Studio window opens on its tab ----
  readonly property bool revealOnFinish: true      // set to false to keep the window closed
  property string pendingTab: ""                   // read by StudioWindow when it opens
  signal revealRequested

  function reveal(tabId) {
    if (!revealOnFinish)
      return;
    pendingTab = tabId;
    revealRequested();
  }

  signal aboutToCapture                  // popups close first, so they are not in the picture

  property string pendingMode: "region"
  property int pendingDelay: 0

  function capture(mode, delay) {
    if (shotBusy)
      return;
    shotNote = "";
    shotBusy = true;
    pendingMode = mode;
    pendingDelay = delay;
    aboutToCapture();
    startShot.restart();                 // a moment for the windows to close
  }

  // the area is chosen first (RegionPicker), then studio-shot takes the picture
  function runShot(area, why) {
    if (!area) {
      shotBusy = false;
      shotNote = why || "";
      return;
    }
    shotProc.command = [Tools.studioShot, "capture", area.mode, String(pendingDelay), area.geom];
    shotProc.running = true;
  }

  Timer {
    id: startShot
    interval: 250
    onTriggered: RegionPicker.resolve(root.pendingMode, "CAPTURE", (area, why) => root.runShot(area, why))
  }

  // never stay "working" for good, whatever happens to the script
  Timer {
    interval: 180000
    running: root.shotBusy
    onTriggered: {
      RegionPicker.cancel();
      shotProc.running = false;
      root.shotBusy = false;
      root.shotNote = "TIMED OUT";
    }
  }

  Process {
    id: shotProc

    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim();
        if (path === "")
          return;
        root.lastShot = path;
        root.shotCount++;
        root.shotBusy = false;               // the Studio window opens below; the button must not still say WORKING
        root.shotNote = "COPIED TO THE CLIPBOARD";
        Sounds.play("screenshot");
        root.reveal("capture");
      }
    }

    stderr: StdioCollector {
      id: shotErr
    }

    onExited: code => {
      root.shotBusy = false;
      // 1 = cancelled in slurp
      if (code !== 0 && code !== 1) {
        const why = shotErr.text.trim().split("\n").pop();
        root.shotNote = "FAILED: " + (why !== "" ? why : "EXIT " + code);
        console.warn("studio-shot exited with " + code + ": " + shotErr.text);
      }
    }
  }

  // SAVE and ANNOTATE work on the last capture
  function saveShot() {
    savProc.command = [Tools.studioShot, "save"];
    savProc.running = true;
  }

  function annotateShot() {
    Annotator.open();
  }

  // SAVE AS asks where to put the picture (studio-shot saveas)
  function saveShotAs() {
    savProc.command = [Tools.studioShot, "saveas"];
    savProc.running = true;
  }

  // IMPORT: any image becomes the last capture (studio-shot asks which file), then opens in the editor
  function importShot() {
    importProc.running = true;
  }

  Process {
    id: importProc
    command: [Tools.studioShot, "import"]
    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim();
        if (path === "")
          return;
        root.lastShot = path;
        root.shotCount++;
        root.shotNote = "IMPORTED";
        Annotator.open();
      }
    }
  }

  // DELETE: forget the last capture. Only the working copy and the editor's untouched copy go; a file
  // saved with SAVE or SAVE AS is somewhere else and stays.
  function deleteShot() {
    if (lastShot === "")
      return;
    if (Annotator.active)
      Annotator.close();
    Quickshell.execDetached(["rm", "-f", lastShot, Annotator.original]);
    lastShot = "";
    shotNote = "DELETED";
    shotCount++;
  }

  function copyShot() {
    if (lastShot !== "")
      Quickshell.execDetached(["sh", "-c", 'exec "$1" < "$2"', "sh", Tools.wlCopy, lastShot]);
  }

  Process {
    id: savProc
    stdout: StdioCollector {
      onStreamFinished: root.shotNote = text.trim() !== "" ? "SAVED TO " + text.trim().replace(/^.*\/Pictures\//, "~/Pictures/") : ""
    }
  }

  // ================= the side mouse buttons =================
  property var sideActions: ({ button4: "none", button5: "none" })

  function setSideAction(button, id) {
    sideActions = Object.assign({}, sideActions, { ["button" + button]: id });
    prefs.save();
  }

  function runSide(button) {
    switch (sideActions["button" + button]) {
    case "record":
      StudioRecorder.toggle();
      break;
    case "playpause":
      togglePlay();
      break;
    case "shot":
      capture(shotMode, shotDelay);
      break;
    }
  }

  // ================= for keybinds: qs ipc call studio ... =================
  IpcHandler {
    target: "studio"

    function shot(mode: string): void {
      root.capture(mode || root.shotMode, root.shotDelay);
    }

    function annotate(): void {
      root.annotateShot();
    }

    function record(action: string): void {
      if (action === "stop")
        StudioRecorder.stop();
      else if (action === "start")
        StudioRecorder.start();
      else
        StudioRecorder.toggle();
    }

    function download(link: string): void {
      StudioDownloader.start(link);
    }

    function side(button: int): void {
      root.runSide(button);
    }

    function playpause(): void {
      root.togglePlay();
    }

    function next(): void {
      root.next();
    }

    function previous(): void {
      root.previous();
    }

    function mute(): void {
      root.toggleMute();
    }
  }

  // ================= remembered between runs =================
  function setShotMode(id) {
    shotMode = id;
    prefs.save();
  }

  function setShotDelay(s) {
    shotDelay = s;
    prefs.save();
  }

  StatePrefs {
    id: prefs
    file: "studio.json"
    data: ({ shotMode: root.shotMode, shotDelay: root.shotDelay, sideActions: root.sideActions })
    onLoaded: saved => {
      if (typeof saved.shotMode === "string")
        root.shotMode = saved.shotMode;      // a monitor that is gone falls back to REGION when used
      if (root.shotDelays.indexOf(saved.shotDelay) !== -1)
        root.shotDelay = saved.shotDelay;
      if (saved.sideActions)
        root.sideActions = Object.assign({}, root.sideActions, saved.sideActions);
    }
  }
}
