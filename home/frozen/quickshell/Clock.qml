pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/calendar.js" as Cal

// The clock the bar button and the calendar share. It runs in the zone picked in the calendar
// (or the system zone when none is picked). The zone's offset comes from `date`, which knows
// daylight saving; the clock itself is plain arithmetic on top, like Weather.qml does for its location.
Singleton {
  id: root

  property string zone: ""              // IANA name, "" = follow the system
  property string systemZone: ""
  property bool alsoSystem: false       // also run timedatectl when a zone is chosen
  property real offsetSec: -new Date().getTimezoneOffset() * 60
  property string detectNote: ""
  property var zones: []

  // Shell lines that select a zone for `date`: $1 is the zone ("" = the system's). They find the
  // zone files even when the shell was not started from a login (no TZDIR), and stop with an
  // error for an unknown zone instead of letting `date` quietly fall back to UTC.
  readonly property string tzSetup: 'z="$1"; shift; if [ -n "$z" ]; then for d in "$TZDIR" /etc/zoneinfo /run/current-system/sw/share/zoneinfo /usr/share/zoneinfo; do if [ -n "$d" ] && [ -e "$d/$z" ]; then export TZDIR="$d" TZ="$z"; break; fi; done; [ -n "$TZ" ] || exit 1; fi; '

  readonly property string zoneName: zone !== "" ? zone : (systemZone !== "" ? systemZone : "SYSTEM")
  readonly property string offsetLabel: Cal.offsetText(offsetSec)

  SystemClock {
    id: ticker
    precision: SystemClock.Seconds
  }

  readonly property real nowMs: ticker.date.getTime()
  readonly property real zoneMs: nowMs + offsetSec * 1000
  readonly property var zd: new Date(zoneMs)
  readonly property int todayDn: Math.floor(zoneMs / 86400000)
  readonly property string dd: Cal.pad2(zd.getUTCDate())
  readonly property string hh: Cal.pad2(zd.getUTCHours())
  readonly property string hh12: Cal.pad2(((zd.getUTCHours() + 11) % 12) + 1)     // 01 to 12
  readonly property string mm: Cal.pad2(zd.getUTCMinutes())
  readonly property string ss: Cal.pad2(zd.getUTCSeconds())
  readonly property string dateText: Cal.DAYS_SHORT[zd.getUTCDay()] + " " + dd + " " + Cal.MONTHS_SHORT[zd.getUTCMonth()]

  function setZone(name) {
    zone = name;
    refresh();
  }

  function choose(name) {
    if (!Cal.looksLikeZone(name))
      return;
    setZone(name);
    if (alsoSystem) {
      setProc.command = [Tools.timedatectl, "set-timezone", name];
      setProc.running = true;
    }
  }

  function refresh() {
    if (offsetProc.running)
      offsetProc.again = true;
    else
      offsetProc.running = true;
  }

  function detect() {
    if (detectProc.running)
      return;
    detectNote = "LOOKING UP...";
    detectProc.tryNo = 0;
    detectProc.running = true;
  }

  function loadZones() {
    if (zones.length === 0 && !zoneListProc.running)
      zoneListProc.running = true;
  }

  function findZones(query, max) {
    const q = query.trim().toLowerCase().replace(/ /g, "_");
    const out = [];
    if (q === "")
      return out;
    for (const z of zones) {
      if (z.toLowerCase().indexOf(q) !== -1) {
        out.push(z);
        if (out.length >= max)
          break;
      }
    }
    return out;
  }

  Process {
    id: offsetProc
    property bool again: false
    command: ["sh", "-c", root.tzSetup + "date +%z", "sh", root.zone]
    stdout: StdioCollector {
      onStreamFinished: {
        const v = Cal.parseOffset(text);
        if (!isNaN(v))
          root.offsetSec = v;
      }
    }
    onExited: {
      if (again) {
        again = false;
        running = true;
      }
    }
  }

  Process {
    id: sysZoneProc
    command: [Tools.timedatectl, "show", "-p", "Timezone", "--value"]
    stdout: StdioCollector {
      onStreamFinished: root.systemZone = text.trim()
    }
  }

  Process {
    id: zoneListProc
    command: [Tools.timedatectl, "list-timezones"]
    stdout: StdioCollector {
      onStreamFinished: root.zones = text.split("\n").filter(s => s !== "")
    }
  }

  // changing the system zone asks for a password through the polkit agent
  Process {
    id: setProc
    stderr: StdioCollector {
      id: setErr
    }
    onExited: code => {
      if (code !== 0)
        Quickshell.execDetached([Tools.notifySend, "--app-name=Calendar", "--", "Could not change the system time zone", setErr.text.trim()]);
      sysZoneProc.running = true;
    }
  }

  Process {
    id: detectProc
    property int tryNo: 0
    readonly property var urls: ["https://ipinfo.io/timezone", "https://ipapi.co/timezone/"]
    command: [Tools.curl, "-fsS", "--max-time", "8", urls[tryNo]]
    stdout: StdioCollector {
      onStreamFinished: {
        const z = text.trim();
        if (Cal.looksLikeZone(z)) {
          root.detectNote = "DETECTED " + z;
          root.choose(z);
        } else if (detectProc.tryNo + 1 < detectProc.urls.length) {
          detectProc.tryNo++;
          retry.start();
        } else {
          root.detectNote = "COULD NOT DETECT (OFFLINE?)";
        }
      }
    }
  }

  Timer {
    id: retry
    interval: 100
    onTriggered: detectProc.running = true
  }

  // daylight saving can change the offset while the shell runs
  Timer {
    interval: 600000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    refresh();
    sysZoneProc.running = true;
  }
}
