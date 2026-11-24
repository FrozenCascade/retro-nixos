pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// Shared system numbers for the bar, the system popup, and anything later.
Singleton {
  id: root

  // ---- settings ----
  // UPower reports 0-1 here. If the battery shows 1% when full, change this to 1.
  readonly property real percentScale: 100
  // true = icons with the power profile badge (battery-050-profile-balanced, ...)
  readonly property bool useProfileIcons: false
  // seconds of history in the graphs (one sample per second)
  readonly property int historyLength: 20

  // Memory icon for the bar (Nerd Font "nf-md-memory"). Replace this string to use another.
  readonly property string memGlyph: "\uDB80\uDF5B"

  // ---- values ----
  property int cpu: 0              // percent
  property int mem: 0              // percent
  property int temp: 0             // degrees C, hottest CPU sensor
  property var cores: []           // percent per logical CPU

  // history, newest last
  property var cpuHistory: []      // percent
  property var memHistory: []      // GB used

  // memory and swap in GB
  property real memUsedGb: 0
  property real memTotalGb: 0
  property int swapPercent: 0
  property real swapUsedGb: 0
  property real swapTotalGb: 0

  // two digits, or XX at 100 and above
  function pad(v) {
    return v >= 100 ? "XX" : String(v).padStart(2, "0");
  }

  readonly property string tempText: pad(temp) + "°C"
  readonly property string cpuText: pad(cpu) + "%"
  readonly property string memText: pad(mem) + "%"

  // ---- cpu, memory and swap, sampled from /proc once a second ----
  property real prevTotal: 0
  property real prevIdle: 0
  property var prevCores: ({})

  FileView {
    id: statFile
    path: "/proc/stat"
    blockLoading: true
  }
  FileView {
    id: memFile
    path: "/proc/meminfo"
    blockLoading: true
  }

  function clampPct(v) {
    return Math.max(0, Math.min(100, Math.round(v)));
  }

  function pushHistory(list, value) {
    const next = list.concat([value]);
    return next.length > historyLength ? next.slice(next.length - historyLength) : next;
  }

  function sample() {
    // ---- cpu: total and per core ----
    statFile.reload();

    const nextCores = [];

    for (const line of statFile.text().split("\n")) {
      if (!line.startsWith("cpu"))
        continue;
      const parts = line.trim().split(/\s+/);
      const label = parts[0];
      const f = parts.slice(1).map(Number);
      const idle = f[3] + (f[4] || 0);
      const total = f.slice(0, 8).reduce((a, b) => a + b, 0);

      if (label === "cpu") {
        if (prevTotal > 0 && total > prevTotal)
          cpu = clampPct(100 * (1 - (idle - prevIdle) / (total - prevTotal)));

        prevTotal = total;
        prevIdle = idle;
      } else {
        const idx = parseInt(label.slice(3));
        const prev = prevCores[idx];

        nextCores.push(prev && total > prev.total ? clampPct(100 * (1 - (idle - prev.idle) / (total - prev.total))) : 0);

        prevCores[idx] = {
          total: total,
          idle: idle
        };
      }
    }

    cores = nextCores;
    cpuHistory = pushHistory(cpuHistory, cpu);

    // ---- memory and swap ----
    memFile.reload();

    const text = memFile.text();
    const kb = name => {
      const m = new RegExp(name + ":\\s+(\\d+)").exec(text);
      return m ? parseInt(m[1]) : 0;
    };

    const totalKb = kb("MemTotal");
    const availKb = kb("MemAvailable");
    const swapTotalKb = kb("SwapTotal");
    const swapFreeKb = kb("SwapFree");
    const gb = v => v / 1048576;

    memTotalGb = gb(totalKb);
    memUsedGb = gb(totalKb - availKb);

    if (totalKb > 0)
      mem = clampPct(100 * (totalKb - availKb) / totalKb);

    swapTotalGb = gb(swapTotalKb);
    swapUsedGb = gb(swapTotalKb - swapFreeKb);
    swapPercent = swapTotalKb > 0 ? clampPct(100 * (swapTotalKb - swapFreeKb) / swapTotalKb) : 0;

    memHistory = pushHistory(memHistory, memUsedGb);
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  // ---- temperature ----
  Process {
    id: tempProc
    command: [Tools.cpuTemp]

    stdout: StdioCollector {
      onStreamFinished: root.temp = parseInt(text.trim()) || 0
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!tempProc.running)
        tempProc.running = true;
    }
  }

  // ---- battery ----
  readonly property var device: {
    if (UPower.displayDevice)
      return UPower.displayDevice;

    const list = UPower.devices && UPower.devices.values ? UPower.devices.values : [];
    return list.find(d => d.isLaptopBattery) || null;
  }

  readonly property bool hasBattery: device !== null && device !== undefined && device.isPresent !== false

  readonly property int battery: hasBattery ? Math.round(device.percentage * percentScale) : 0

  readonly property bool charging: hasBattery && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)

  readonly property bool full: hasBattery && device.state === UPowerDeviceState.FullyCharged

  function formatDuration(seconds) {
    if (!seconds || seconds <= 0)
      return "--";

    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);

    return h > 0 ? h + "h " + String(m).padStart(2, "0") + "m" : m + "m";
  }

  // "3h 20m LEFT", "1h 05m TO FULL", ...
  readonly property string batteryTimeText: {
    if (!hasBattery)
      return "";

    if (full)
      return "FULLY CHARGED";

    if (charging)
      return device.timeToFull > 0 ? formatDuration(device.timeToFull) + " TO FULL" : "CHARGING";

    return device.timeToEmpty > 0 ? formatDuration(device.timeToEmpty) + " LEFT" : "--";
  }

  // ---- power profile: "performance", "balanced" or "power-saver" ----
  readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

  readonly property string profileName: {
    const p = PowerProfiles.profile;

    if (p === PowerProfile.PowerSaver)
      return "power-saver";
    if (p === PowerProfile.Performance)
      return "performance";

    return "balanced";
  }

  function setProfileByName(name) {
    if (name === "performance") {
      if (hasPerformance)
        PowerProfiles.profile = PowerProfile.Performance;
    } else if (name === "power-saver") {
      PowerProfiles.profile = PowerProfile.PowerSaver;
    } else {
      PowerProfiles.profile = PowerProfile.Balanced;
    }
  }

  // delta +1 = toward performance, -1 = toward power saving
  function stepProfile(delta) {
    const order = ["power-saver", "balanced", "performance"];
    let i = order.indexOf(profileName) + delta;

    i = Math.max(0, Math.min(order.length - 1, i));

    setProfileByName(order[i]);
  }

  readonly property string profileSuffix: {
    if (!useProfileIcons)
      return "";

    if (profileName === "power-saver")
      return "-profile-powersave";
    if (profileName === "performance")
      return "-profile-performance";

    return "-profile-balanced";
  }

  // icon name in your pack: battery-050, battery-050-charging, battery-100-charged, ...
  readonly property string batteryIconName: {
    if (!hasBattery)
      return "";

    const level = Math.max(0, Math.min(100, Math.round(battery / 10) * 10));

    if (level === 100 && full)
      return "battery-100-charged";

    let name = "battery-" + String(level).padStart(3, "0");

    if (charging)
      name += "-charging";

    return name + profileSuffix;
  }
}
