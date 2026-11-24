pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "lib/display.js" as Disp

// Screen brightness, night light and the laptop screen switch, in one place.
//
// Every monitor is controlled in the best way it allows (its "kind"):
//   backlight   the laptop panel, through brightnessctl
//   ddc         an external monitor that answers DDC/CI, through ddcutil
//   soft        any other monitor: a dark layer over the picture (components/display/SoftDim.qml).
//               This is what a monitor behind an HDMI splitter gets, because splitters block DDC/CI.
// Detection runs at start, and again when monitors are plugged in or out.
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property real panelMin: 0.01         // darkest laptop backlight (0 would switch it off)
  readonly property real softMin: 0.2           // darkest software dimming (1 = none)
  readonly property real step: 0.05             // one scroll notch
  readonly property int nightMin: 2500          // night light range, in Kelvin
  readonly property int nightMax: 6500

  signal poked(string monitor)                  // brightness changed from the bar or a key: show the pop-up

  // ================= which monitor, and how =================
  property var levels: ({})                     // monitor name -> 0..1 for backlight and ddc monitors
  property var softLevels: ({})                 // monitor name -> softMin..1
  property var buses: ({})                      // monitor name -> i2c bus, from ddcutil
  property bool detecting: false

  // the monitor the bar button and the keys control: the one you are working on
  readonly property string current: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Settings.externalMonitor
  readonly property real currentLevel: levelOf(current)

  function kindOf(name) {
    if (name === Settings.laptopMonitor)
      return "backlight";
    return buses[name] !== undefined ? "ddc" : "soft";
  }

  function levelOf(name) {
    const table = kindOf(name) === "soft" ? softLevels : levels;
    return table[name] !== undefined ? table[name] : 1;
  }

  // a bulb that fills as the screen gets brighter
  function bulb(level) {
    return level < 0.34 ? Glyphs.bulbOutline : (level < 0.67 ? Glyphs.bulb : Glyphs.bulbOn);
  }

  function withKey(table, key, value) {
    const copy = Object.assign({}, table);
    copy[key] = value;
    return copy;
  }

  function setBrightness(name, v) {
    const kind = kindOf(name);
    if (kind === "backlight") {
      const x = Math.max(panelMin, Math.min(1, v));
      levels = withKey(levels, name, x);
      if (!laptopHidden)
        setPanel(x);
    } else if (kind === "ddc") {
      const x = Math.max(0, Math.min(1, v));
      levels = withKey(levels, name, x);
      ddcPending[name] = Math.round(x * 100);
      ddcTimer.restart();
    } else {
      softLevels = withKey(softLevels, name, Math.max(softMin, Math.min(1, v)));
      saveSoon.restart();
    }
  }

  // one notch up or down for one monitor, then the pop-up
  function nudge(name, dir) {
    setBrightness(name, Math.round((levelOf(name) + dir * step) * 100) / 100);
    poked(name);
  }

  // one notch for every monitor at once (the bar button's wheel and the keys); each keeps its own level
  function nudgeAll(dir) {
    Array.from(Quickshell.screens).forEach(s => setBrightness(s.name, Math.round((levelOf(s.name) + dir * step) * 100) / 100));
    poked(current);
  }

  // ================= laptop panel =================
  // Only the "backlight" class is touched (a laptop also has keyboard and LED devices that brightnessctl
  // would otherwise pick). The newest value wins if several arrive while one is being applied.
  property real panelWanted: -1

  function setPanel(x) {
    panelWanted = x;
    if (!panelSetProc.running)
      applyPanel();
  }

  function applyPanel() {
    if (panelWanted < 0)
      return;
    panelSetProc.command = [Tools.brightnessctl, "-c", "backlight", "set", Math.round(panelWanted * 100) + "%"];
    panelWanted = -1;
    panelSetProc.running = true;
  }

  Process {
    id: panelSetProc
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("DisplayState brightnessctl: " + text.trim());
      }
    }
    onExited: root.applyPanel()
  }

  function refreshPanel() {
    if (!panelProc.running && !laptopHidden)
      panelProc.running = true;
  }

  Process {
    id: panelProc
    command: [Tools.brightnessctl, "-c", "backlight", "-m"]
    stdout: StdioCollector {
      onStreamFinished: {
        // name,class,value,percent,max
        const f = text.trim().split("\n")[0].split(",");
        const pct = parseInt(f[3]);
        if (!isNaN(pct))
          root.levels = root.withKey(root.levels, Settings.laptopMonitor, pct / 100);
      }
    }
  }

  // ================= external monitors over DDC/CI =================
  property var ddcPending: ({})                 // monitor name -> percent waiting to be sent
  property var readQueue: []
  property string readName: ""

  // ddcutil is slow (about a second per call), so changes are bundled and sent one at a time
  Timer {
    id: ddcTimer
    interval: 300
    onTriggered: root.flushDdc()
  }

  function flushDdc() {
    const names = Object.keys(ddcPending);
    if (names.length === 0)
      return;
    if (ddcSetProc.running) {
      ddcTimer.restart();
      return;
    }
    const name = names[0];
    const pct = ddcPending[name];
    delete ddcPending[name];
    ddcSetProc.command = [Tools.ddcutil, "--bus", String(buses[name]), "setvcp", "10", String(pct), "--noverify"];
    ddcSetProc.running = true;
  }

  Process {
    id: ddcSetProc
    onExited: {
      if (Object.keys(root.ddcPending).length > 0)
        ddcTimer.restart();
    }
  }

  function detect() {
    if (detecting)
      return;
    detecting = true;
    detectProc.running = true;
  }

  Process {
    id: detectProc
    command: [Tools.ddcutil, "detect", "--brief"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.buses = Disp.parseDdcDetect(text);
        root.detecting = false;
        root.readQueue = Object.keys(root.buses);
        root.readNext();
      }
    }
  }

  // reads each DDC monitor's current brightness, one after the other
  function readNext() {
    if (vcpProc.running || readQueue.length === 0)
      return;
    readName = readQueue[0];
    readQueue = readQueue.slice(1);
    vcpProc.command = [Tools.ddcutil, "--bus", String(buses[readName]), "getvcp", "10", "--brief"];
    vcpProc.running = true;
  }

  Process {
    id: vcpProc
    stdout: StdioCollector {
      onStreamFinished: {
        const v = Disp.parseVcp(text);
        if (v && v.max > 0)
          root.levels = root.withKey(root.levels, root.readName, v.cur / v.max);
        root.readNext();
      }
    }
  }

  // plugging a monitor in or out can change what answers DDC
  Connections {
    target: Quickshell

    function onScreensChanged() {
      detectSoon.restart();
    }
  }

  Timer {
    id: detectSoon
    interval: 3000
    onTriggered: root.detect()
  }

  // ================= laptop screen switch =================
  // Hidden = black cover over the laptop screen (components/display/LaptopBlank.qml) and the backlight
  // at zero. Touching the screen with the pointer brings it back.
  property bool laptopHidden: false

  // Only a screen that is not the primary can be switched off, so there is always a screen left on:
  // the laptop with a main monitor next to it. A laptop on its own (or the main one) cannot be hidden,
  // and unplugging the main monitor brings a hidden laptop screen back.
  readonly property bool canHideLaptop: Array.from(Quickshell.screens).some(s => s.name === Settings.externalMonitor) && Array.from(Quickshell.screens).some(s => s.name === Settings.laptopMonitor)
  onCanHideLaptopChanged: {
    if (!canHideLaptop && laptopHidden)
      setLaptopHidden(false);
  }
  property real restoreLevel: 0                 // the backlight to return to; kept on disk while hidden

  function setLaptopHidden(hidden) {
    if (hidden === laptopHidden || (hidden && !canHideLaptop))
      return;
    if (hidden) {
      restoreLevel = levelOf(Settings.laptopMonitor);
      laptopHidden = true;
      setPanel(0);
    } else {
      laptopHidden = false;
      restorePanel();
    }
    saveSoon.restart();
  }

  function restorePanel() {
    const x = Math.max(restoreLevel, panelMin);
    setPanel(x);
    levels = withKey(levels, Settings.laptopMonitor, x);
    restoreLevel = 0;
  }

  // ================= night light (hyprsunset) =================
  property bool nightOn: false
  property int nightTemp: 4000                  // the tint while night light is on
  property int dayTemp: 6500                    // the tint the rest of the time (6500 = none)
  property bool nightSchedule: false
  property string nightFrom: "20:00"
  property string nightTo: "07:00"
  property int minutes: nowMinutes()

  function nowMinutes() {
    const d = new Date();
    return d.getHours() * 60 + d.getMinutes();
  }

  // with a schedule the clock decides, otherwise the switch
  readonly property bool nightWanted: nightSchedule ? Disp.inWindow(minutes, Disp.minutesOf(nightFrom), Disp.minutesOf(nightTo)) : nightOn

  readonly property int tintNow: nightWanted ? nightTemp : dayTemp

  function applyNight() {
    if (tintNow >= nightMax)
      Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
    else
      Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(tintNow)]);
  }

  onTintNowChanged: applyNight()
  onNightTempChanged: saveSoon.restart()
  onDayTempChanged: saveSoon.restart()
  onNightOnChanged: saveSoon.restart()
  onNightFromChanged: saveSoon.restart()
  onNightToChanged: saveSoon.restart()
  onNightScheduleChanged: {
    minutes = nowMinutes();
    saveSoon.restart();
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.nightSchedule
    onTriggered: root.minutes = root.nowMinutes()
  }

  // ================= remembered between runs =================
  function save() {
    prefs.setText(JSON.stringify({
      soft: softLevels,
      restoreLevel: restoreLevel,
      night: { on: nightOn, temp: nightTemp, day: dayTemp, schedule: nightSchedule, from: nightFrom, to: nightTo }
    }));
  }

  Timer {
    id: saveSoon
    interval: 500
    onTriggered: root.save()
  }

  FileView {
    id: prefs
    path: Quickshell.statePath("display.json")
    onLoaded: {
      try {
        const d = JSON.parse(prefs.text());
        root.softLevels = d.soft || {};
        const n = d.night || {};
        root.nightOn = n.on === true;
        root.nightTemp = n.temp || 4000;
        root.dayTemp = n.day || 6500;
        root.nightSchedule = n.schedule === true;
        root.nightFrom = n.from || "20:00";
        root.nightTo = n.to || "07:00";
        // the shell stopped while the laptop screen was hidden: give the backlight back
        if (d.restoreLevel > 0) {
          root.restoreLevel = d.restoreLevel;
          root.restorePanel();
          root.save();
        }
      } catch (e) {}
    }
  }

  // for keybinds:  qs ipc call display up   /  down  /  toggleLaptop
  IpcHandler {
    target: "display"

    function up(): void {
      root.nudgeAll(1);
    }

    function down(): void {
      root.nudgeAll(-1);
    }

    function toggleLaptop(): void {
      root.setLaptopHidden(!root.laptopHidden);
    }
  }

  // start-up work waits a moment so it does not slow the shell down
  Timer {
    interval: 3000
    running: true
    onTriggered: {
      root.refreshPanel();
      root.detect();
      root.applyNight();
    }
  }
}
