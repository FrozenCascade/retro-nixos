pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.components.shared

// Choosing the area for a screenshot or a recording. Both ask here:
//   RegionPicker.resolve(mode, "CAPTURE", (area, why) => ...)
// `area` is { mode, geom } (geom is "x,y wxh", the way grim and slurp write it, in the compositor's
// coordinates) or null when it was cancelled; `why` is a short reason to show when there is one.
// REGION opens the selector (RegionOverlay.qml, one window per monitor, which edits the numbers below);
// WINDOW points at a window with slurp; LAST REGION repeats the previous area; a monitor's name and
// ALL MONITORS need no area at all.
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property int settleMs: 280       // wait after the selector closes, so it is gone before the picture
                                            // (raise it if the dimming ever shows up in a capture)
  readonly property int minSize: 4          // smallest area, in pixels
  readonly property bool startFromLast: false   // true: the selector opens with the previous area already drawn,
                                                // so ENTER repeats it (LAST REGION works either way)

  // what can be captured or recorded; the monitors are whichever are connected right now
  readonly property var areas: [
    { id: "region", name: "REGION" },
    { id: "window", name: "WINDOW" }
  ].concat(Array.from(Quickshell.screens).map(s => ({ id: s.name, name: s.name })), [
    { id: "screen", name: "ALL MONITORS" },
    { id: "last", name: "LAST REGION" }
  ])

  // the same without ALL MONITORS: the recorder only takes one monitor at a time
  readonly property var recordAreas: areas.filter(a => a.id !== "screen")

  // ---- the selector's state (logical pixels, compositor coordinates) ----
  property bool active: false
  property string verb: "CAPTURE"           // shown on the selector's hint: ENTER: CAPTURE
  property string screenName: ""            // the monitor the selection is on
  property int selX: 0
  property int selY: 0
  property int selW: 0
  property int selH: 0
  readonly property bool hasSel: selW >= minSize && selH >= minSize

  property string last: ""                  // the previous area, "x,y wxh"; kept between runs

  property var pending: null                // who is waiting for the answer
  property string chosen: ""

  function setSel(name, x, y, w, h) {
    screenName = name;
    selX = x;
    selY = y;
    selW = w;
    selH = h;
  }

  // ---- asking ----
  function resolve(mode, verbName, done) {
    if (!areas.some(a => a.id === mode))
      mode = "region";                      // a monitor that is gone, or an old setting

    if (mode === "region") {
      open(verbName, done);
    } else if (mode === "window") {
      pickWindow(done);
    } else if (mode === "last") {
      if (last === "")
        done(null, "NO REGION YET");
      else
        done({ mode: "region", geom: last });
    } else {
      done({ mode: mode, geom: "" });
    }
  }

  function remember(geom) {
    last = geom;
    prefs.save();
  }

  // ---- the selector ----
  function open(verbName, done) {
    if (active || pending) {
      done(null, "");
      return;
    }
    verb = verbName;
    pending = done;
    seed();
    active = true;
  }

  // start empty, or (startFromLast) from the previous area when it still fits on a monitor
  function seed() {
    setSel("", 0, 0, 0, 0);
    if (!startFromLast)
      return;
    const m = /^(-?\d+),(-?\d+) (\d+)x(\d+)$/.exec(last);
    if (!m)
      return;
    const x = +m[1], y = +m[2], w = +m[3], h = +m[4];
    for (const s of Array.from(Quickshell.screens)) {
      if (x >= s.x && y >= s.y && x + w <= s.x + s.width && y + h <= s.y + s.height) {
        setSel(s.name, x, y, w, h);
        return;
      }
    }
  }

  // right click: take the current area back, the selector stays open
  function retract() {
    setSel("", 0, 0, 0, 0);
  }

  function confirm() {
    if (!active || !hasSel)
      return;
    chosen = selX + "," + selY + " " + selW + "x" + selH;
    remember(chosen);
    active = false;
    settle.restart();
  }

  function cancel() {
    const done = pending;
    pending = null;
    active = false;
    settle.stop();
    winProc.running = false;
    if (done)
      done(null, "");
  }

  Timer {
    id: settle
    interval: root.settleMs
    onTriggered: {
      const done = root.pending;
      root.pending = null;
      if (done)
        done({ mode: "region", geom: root.chosen });
    }
  }

  // ---- WINDOW: slurp over the windows that are on screen (studio-shot window) ----
  function pickWindow(done) {
    if (pending) {
      done(null, "");
      return;
    }
    pending = done;
    winProc.command = [Tools.studioShot, "window"];
    winProc.running = true;
  }

  Process {
    id: winProc

    stdout: StdioCollector {
      onStreamFinished: {
        const done = root.pending;
        root.pending = null;
        if (!done)
          return;
        const geom = text.trim();
        if (geom === "") {
          done(null, "");
          return;
        }
        root.remember(geom);
        done({ mode: "region", geom: geom });
      }
    }
  }

  // ---- remembered between runs ----
  StatePrefs {
    id: prefs
    file: "region.json"
    data: ({ last: root.last })
    onLoaded: saved => {
      if (typeof saved.last === "string" && /^-?\d+,-?\d+ \d+x\d+$/.test(saved.last))
        root.last = saved.last;
    }
  }
}
