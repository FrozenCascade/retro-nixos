pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Everything the wallpaper layer needs to know, per ROLE. Like the rest of the shell there are two roles:
//   primary    the main monitor (Settings.externalMonitor), or the laptop screen when that monitor is not connected
//   secondary  the laptop screen next to the main monitor
// So when the main monitor is unplugged the laptop takes over the primary's settings and look.
// The functions below take a monitor NAME and look up its role. Each role has:
//   image         a picture file, "" = the theme's picture (Settings.wallpaper)
//   defaultMode   the mode the monitor starts in at every login
//   decor         extras drawn in front of the picture: { cava: true/false }
//   plus the options of each mode (selection colour, music layout, rain colour/speed/density)
// The mode you pick in the Display window is for this session; DEFAULT makes it the starting one.
// The cava feed also lives here, so one cava process serves every monitor and runs only while a bar shows.
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property var modes: [
    { id: "blank", name: "BLANK" },
    { id: "desktop", name: "DESKTOP" },
    { id: "music", name: "MUSIC" },
    { id: "matrix", name: "MATRIX" },
    { id: "snake", name: "SNAKE" }
  ]
  // the colours offered for selection boxes, rain and bars: [id, label, where it comes from in Theme]
  readonly property var accents: [
    { id: "white", label: "WHITE" },
    { id: "orange", label: "ORANGE" },
    { id: "yellow", label: "YELLOW" },
    { id: "green", label: "GREEN" },
    { id: "aqua", label: "AQUA" },
    { id: "blue", label: "BLUE" },
    { id: "purple", label: "PURPLE" },
    { id: "red", label: "RED" }
  ]
  readonly property var pictureDirs: [Quickshell.env("HOME") + "/Pictures/Wallpapers"]          // searched two folders deep
  readonly property var rainFpsChoices: [20, 30, 45, 60]                                        // redraws per second for the rain; lower = lighter
  readonly property int cavaBars: 48                                                             // keep equal to bars in the cava config

  // Only these are kept per monitor. Every other setting (colours, rain speed, bars, layout) is shared by all.
  readonly property var perMonitor: ["image", "defaultMode", "rain"]

  // what a monitor has before anything is saved for it
  readonly property var defaults: ({
    image: "",
    defaultMode: "blank",
    rain: false,                  // falling rain over the picture, under the mode (per monitor)
    selectColor: "orange",
    lockImage: "",                // "" = the lock screen shows the desktop picture
    lockBlur: true,
    loginImage: "",               // "" = the login screen shows the wallpaper bundled with the theme
    musicLayout: "bars",          // "bars" or "centered"
    cavaColor: "orange",          // the audio bars, in the music mode and as decor
    matrixColor: "green",
    matrixSpeed: 0.5,             // 0..1
    matrixDensity: 0.5,           // 0..1
    rainColor: "aqua",            // the rain over the picture (not the matrix mode)
    rainSpeed: 0.5,               // 0..1
    rainDensity: 0.5,             // 0..1
    rainSlant: 0.6,               // 0..1: 0.5 falls straight down, higher leans to the right
    rainFps: 30                   // one of rainFpsChoices
  })

  property var saved: ({})        // role -> only what was changed
  property var everyone: ({})     // the shared settings, same for every monitor
  property var modeNow: ({})      // role -> mode picked this session

  // the theme colour behind an accent id (written out, not looked up by name, so a typo shows up as orange)
  function accentColor(id) {
    return ({
      white: Theme.fg,
      orange: Theme.orange,
      yellow: Theme.yellow,
      green: Theme.green,
      aqua: Theme.aqua,
      blue: Theme.blue,
      purple: Theme.purple,
      red: Theme.red
    })[id] || Theme.orange;
  }

  // ---- roles ----
  readonly property bool externalUp: Array.from(Quickshell.screens).some(s => s.name === Settings.externalMonitor)

  function roleOf(name) {
    if (name === Settings.externalMonitor)
      return "primary";
    if (name === Settings.laptopMonitor && !externalUp)
      return "primary";
    return "secondary";
  }

  function withKey(table, key, value) {
    const copy = Object.assign({}, table);
    copy[key] = value;
    return copy;
  }

  // a monitor's full settings: the defaults with its own changes on top
  function cfg(name) {
    const mine = saved[roleOf(name)] || {};
    const own = {};
    for (const key of perMonitor)        // leftovers of older per-role saves are ignored
      if (key in mine)
        own[key] = mine[key];
    const out = Object.assign({}, defaults, everyone, own);
    return out;
  }

  function set(name, key, value) {
    if (perMonitor.includes(key)) {
      const role = roleOf(name);
      saved = withKey(saved, role, withKey(saved[role] || {}, key, value));
    } else {
      everyone = withKey(everyone, key, value);
    }
    console.log("wallpaper: " + name + " " + key + " = " + JSON.stringify(value));
    saveSoon.restart();
  }

  // older save files had every setting per monitor: the main monitor's become the shared ones
  function migrate(table) {
    const main = table.primary || {};
    const shared = {};
    for (const key of Object.keys(main))
      if (!perMonitor.includes(key))
        shared[key] = main[key];
    return shared;
  }

  function modeOf(name) {
    return modeNow[roleOf(name)] || cfg(name).defaultMode;
  }

  function setMode(name, id) {
    modeNow = withKey(modeNow, roleOf(name), id);
  }

  // ---- login screen (SDDM) ----
  // The login theme cannot read your home folder, so the picture is copied to a folder sddm.nix creates.
  readonly property string loginDir: "/var/lib/sddm-retro"

  function setLoginImage(path) {
    loginCopy.command = path === "" ? ["rm", "-f", loginDir + "/background"] : ["install", "-m", "644", path, loginDir + "/background"];
    loginCopy.running = true;
    set("", "loginImage", path);
  }

  Process {
    id: loginCopy
  }

  function modeName(id) {
    const m = modes.find(x => x.id === id);
    return m ? m.name : id.toUpperCase();
  }

  // the picture file of a monitor, with the theme's picture as the fallback
  function imageOf(name) {
    const own = cfg(name).image;
    return own !== "" ? own : (Settings.wallpaper || "");
  }

  function fileUrl(name) {
    const path = imageOf(name);
    return path !== "" ? "file://" + path : "";
  }

  // ================= pictures to choose from =================
  property var pictures: []

  function scanPictures() {
    if (!findProc.running)
      findProc.running = true;
  }

  Process {
    id: findProc
    command: ["find"].concat(root.pictureDirs).concat(["-maxdepth", "2", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.avif", ")"])
    stdout: StdioCollector {
      onStreamFinished: root.pictures = text.split("\n").filter(l => l !== "").sort()
    }
  }

  // ================= cava (audio bars) =================
  property int cavaUsers: 0       // how many bar displays are alive right now
  property var bars: []           // 0..1 per bar, about 30 times a second

  Process {
    running: root.cavaUsers > 0
    command: [Tools.cava, "-p", Tools.cavaConfig]
    stdout: SplitParser {
      onRead: line => root.bars = line.split(";").filter(s => s !== "").map(s => Number(s) / 100)
    }
  }

  // ================= remembered between runs =================
  Timer {
    id: saveSoon
    interval: 500
    onTriggered: prefs.setText(JSON.stringify({ roles: root.saved, everyone: root.everyone }))
  }

  FileView {
    id: prefs
    path: Quickshell.statePath("wallpaper.json")
    onLoaded: {
      try {
        const data = JSON.parse(prefs.text());
        root.saved = data.roles || {};
        root.everyone = data.everyone || root.migrate(root.saved);
      } catch (e) {}
    }
  }
}
