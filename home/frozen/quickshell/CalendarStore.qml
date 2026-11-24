pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/calendar.js" as Cal

// What the calendar remembers (calendar.json in Quickshell's state folder), the downloaded holiday
// lists (holidays.json), the reminder alarm, and the "what is on this day?" questions the grid asks.
Singleton {
  id: root

  function defaults() {
    return {
      showReminders: true,
      showEvents: true,
      showHolidays: true,
      showMoon: false,
      showSeasons: false,
      weekStartsMonday: false,
      clock12: false,
      srcUsFederal: true,
      srcUsObservances: false,
      countries: [],            // two-letter codes, downloaded from Nager.Date
      zone: "",
      alsoSystemZone: false,
      flakeNag: true,
      flakeNagDays: 14
    };
  }

  property var settings: defaults()
  property var events: []        // { id, title, dn, dnEnd, time }   time "" = all day
  property var reminders: []     // { id, title, dn, minute, zone, epoch, length, notify, fired }
  property var holidayData: ({ nager: {} })
  property bool loaded: false
  property bool writable: true
  property int rev: 0            // bumps on every change, so bindings that call the functions below refresh
  property var hidden: ({})      // ids waiting for their undo time to end
  property var cache: ({ hol: {}, astro: {}, moon: {} })
  property string fetchNote: ""
  property var queue: []
  property var tried: ({})

  function start() {
    return loaded;
  }

  function uid() {
    return Date.now().toString(36) + Math.floor(Math.random() * 1679616).toString(36);
  }

  function brief(text, max) {
    const s = String(text || "").replace(/\s+/g, " ").trim();
    return s.length > max ? s.slice(0, max - 1) + "…" : s;
  }

  // ---------------------------------------------------------------- saving and loading
  function load(raw) {
    if (raw) {
      try {
        const d = JSON.parse(raw);
        settings = Object.assign(defaults(), d.settings || {});
        events = (d.events || []).map(e => ({ id: e.id || uid(), title: String(e.title || ""), dn: Cal.dnOfKey(e.date), dnEnd: Cal.dnOfKey(e.endDate || e.date), time: e.time || "" })).filter(e => !isNaN(e.dn) && !isNaN(e.dnEnd));
        reminders = (d.reminders || []).map(r => ({ id: r.id || uid(), title: String(r.title || ""), dn: Cal.dnOfKey(r.date), minute: +r.minute || 0, zone: r.zone || "", epoch: +r.epoch || 0, length: +r.length || 0, notify: !!r.notify, fired: !!r.fired })).filter(r => !isNaN(r.dn));
      } catch (e) {
        writable = false;     // leave the file alone rather than overwrite something we could not read
        console.warn("calendar.json could not be read, so nothing will be saved: " + e);
      }
    }
    loaded = true;
    Clock.alsoSystem = settings.alsoSystemZone;
    Clock.setZone(settings.zone);
    invalidate();
    ensureYear(Clock.zd.getUTCFullYear(), false);
  }

  function changed() {
    invalidate();
    saveTimer.restart();
  }

  function invalidate() {
    cache = ({ hol: {}, astro: {}, moon: {} });
    rev++;
  }

  function saveNow() {
    saveTimer.stop();
    if (!loaded || !writable)
      return;
    file.setText(JSON.stringify({
      settings: settings,
      events: events.map(e => ({ id: e.id, title: e.title, date: Cal.keyOf(e.dn), endDate: Cal.keyOf(e.dnEnd), time: e.time })),
      reminders: reminders.map(r => ({ id: r.id, title: r.title, date: Cal.keyOf(r.dn), minute: r.minute, zone: r.zone, epoch: r.epoch, length: r.length, notify: r.notify, fired: r.fired }))
    }, null, 1));
  }

  function setSetting(key, value) {
    const s = Object.assign({}, settings);
    s[key] = value;
    settings = s;
    if (key === "alsoSystemZone")
      Clock.alsoSystem = value;
    changed();
  }

  FileView {
    id: file
    path: Quickshell.statePath("calendar.json")
    // written on the spot, not on a background thread: the last save happens while the shell shuts down,
    // and an asynchronous write there crashes it
    blockWrites: true
    onLoaded: root.load(file.text())
    onLoadFailed: root.load("")
  }

  FileView {
    id: holidayFile
    path: Quickshell.statePath("holidays.json")
    onLoaded: {
      try {
        const d = JSON.parse(holidayFile.text());
        root.holidayData = { nager: d.nager || {} };
        root.invalidate();
      } catch (e) {}
    }
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: root.saveNow()
  }

  Timer {
    id: holidaySave
    interval: 600
    onTriggered: holidayFile.setText(JSON.stringify(root.holidayData))
  }

  Component.onDestruction: saveNow()

  // keep the saved zone in step with what the Clock uses
  Connections {
    target: Clock
    function onZoneChanged() {
      if (root.loaded && root.settings.zone !== Clock.zone)
        root.setSetting("zone", Clock.zone);
    }
  }

  // ---------------------------------------------------------------- events and reminders
  function addEvent(title, dn, dnEnd, time) {
    events = events.concat([{ id: uid(), title: title, dn: dn, dnEnd: Math.max(dn, dnEnd), time: time }]);
    changed();
  }

  // The exact moment depends on daylight saving on that date, so `date` works it out.
  // with an id, it replaces that reminder (an edit)
  function addReminder(title, dn, minute, length, notify, id) {
    const rec = { id: id || uid(), title: title, dn: dn, minute: minute, zone: Clock.zone, epoch: 0, length: length, notify: notify, fired: false };
    epochProc.jobs = epochProc.jobs.concat([rec]);
    epochPump.start();
  }

  Timer {
    id: epochPump
    interval: 20
    onTriggered: {
      if (epochProc.running) {
        start();
        return;
      }
      if (epochProc.jobs.length === 0)
        return;
      epochProc.job = epochProc.jobs[0];
      epochProc.jobs = epochProc.jobs.slice(1);
      epochProc.running = true;
    }
  }

  Process {
    id: epochProc
    property var jobs: []
    property var job: null
    command: ["sh", "-c", Clock.tzSetup + 'date -d "$1" +%s', "sh", job ? job.zone : "", job ? Cal.keyOf(job.dn) + " " + Cal.clockText(job.minute) : ""]
    stdout: StdioCollector {
      onStreamFinished: {
        const j = epochProc.job;
        if (!j)
          return;
        const s = parseInt(text.trim());
        j.epoch = isNaN(s) ? j.dn * 86400000 + j.minute * 60000 - Clock.offsetSec * 1000 : s * 1000;
        j.fired = j.epoch < Date.now() - 60000;       // already past: no alarm
        root.reminders = root.reminders.filter(r => r.id !== j.id).concat([j]);
        root.changed();
        epochPump.start();
      }
    }
  }

  function updateEvent(id, title, dn, dnEnd, time) {
    events = events.map(e => e.id === id ? { id: id, title: title, dn: dn, dnEnd: Math.max(dn, dnEnd), time: time } : e);
    changed();
  }

  function item(kind, id) {
    return (kind === "event" ? events : reminders).find(x => x.id === id) || null;
  }

  function extendReminder(id, delta) {
    reminders = reminders.map(r => r.id === id ? Object.assign({}, r, { length: Math.max(0, Math.min(525600, r.length + delta)) }) : r);
    changed();
  }

  function setNotify(id, on) {
    reminders = reminders.map(r => r.id === id ? Object.assign({}, r, { notify: on, fired: on ? r.epoch <= Date.now() : r.fired }) : r);
    changed();
  }

  function removeItem(kind, id, title) {
    hidden = Object.assign({}, hidden, { [id]: true });
    invalidate();
    QuickUndo.stage((kind === "event" ? "EVENT  " : "REMINDER  ") + brief(title, 22), () => {
      const h = Object.assign({}, hidden);
      delete h[id];
      hidden = h;
      invalidate();
    }, () => {
      events = events.filter(e => e.id !== id);
      reminders = reminders.filter(r => r.id !== id);
      const h = Object.assign({}, hidden);
      delete h[id];
      hidden = h;
      changed();
    });
  }

  function reminderEndDn(r) {
    return Math.floor((r.dn * 1440 + r.minute + Math.max(r.length - 1, 0)) / 1440);
  }

  // ---------------------------------------------------------------- the alarm
  Timer {
    interval: 10000
    repeat: true
    running: root.loaded
    triggeredOnStart: true
    onTriggered: {
      const now = Date.now();
      let dirty = false;
      for (const r of root.reminders) {
        if (r.notify && !r.fired && r.epoch > 0 && r.epoch <= now && !root.hidden[r.id]) {
          r.fired = true;
          dirty = true;
          const late = now - r.epoch > 120000;
          const body = (late ? "Missed, was due " : "") + Cal.clockText(r.minute) + (r.length > 0 ? "  for " + Cal.lengthText(r.length) : "");
          Sounds.play("alarm");
          Quickshell.execDetached([Tools.notifySend, "--app-name=Calendar", "--icon=appointment-soon", "--", r.title, body]);
        }
      }
      if (dirty) {
        root.reminders = root.reminders.slice();
        root.changed();
      }
    }
  }

  // ---------------------------------------------------------------- holidays
  function holidayIndex(year) {
    const c = cache.hol;
    if (c[year])
      return c[year];
    const idx = {};
    const add = (dn, name, src) => {
      (idx[dn] = idx[dn] || []).push({ name: name, src: src });
    };
    if (settings.srcUsFederal)
      for (const h of Cal.holidaysUS(year))
        add(h.dn, h.name, "US FEDERAL");
    if (settings.srcUsObservances)
      for (const h of Cal.observancesUS(year))
        add(h.dn, h.name, "OBSERVANCE");
    for (const code of settings.countries) {
      const list = (holidayData.nager[code] || {})[year];
      if (list)
        for (const h of list)
          add(h.dn, h.name, code);
    }
    c[year] = idx;
    return idx;
  }

  function ensureYear(year, force) {
    if (!loaded)
      return;
    for (const code of settings.countries) {
      if (force || !(holidayData.nager[code] || {})[year])
        queueJob({ code: code, year: year, url: "https://date.nager.at/api/v3/PublicHolidays/" + year + "/" + code }, force);
    }
  }

  function queueJob(job, force) {
    job.key = job.code + job.year;
    if (!force && Date.now() - (tried[job.key] || 0) < 600000)
      return;
    if (queue.some(j => j.key === job.key) || (fetchProc.job && fetchProc.running && fetchProc.job.key === job.key))
      return;
    queue = queue.concat([job]);
    pump.start();
  }

  function refreshHolidays(year) {
    for (const y of [year - 1, year, year + 1])
      ensureYear(y, true);
  }

  function addCountry(code) {
    code = String(code).trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(code) || settings.countries.indexOf(code) !== -1)
      return;
    setSetting("countries", settings.countries.concat([code]));
    refreshHolidays(Clock.zd.getUTCFullYear());
  }

  function removeCountry(code) {
    setSetting("countries", settings.countries.filter(c => c !== code));
  }

  Timer {
    id: pump
    interval: 60
    onTriggered: {
      if (fetchProc.running) {
        start();
        return;
      }
      if (root.queue.length === 0)
        return;
      const job = root.queue[0];
      root.queue = root.queue.slice(1);
      root.tried[job.key] = Date.now();
      fetchProc.job = job;
      root.fetchNote = "FETCHING " + job.code + " " + job.year + "...";
      fetchProc.running = true;
    }
  }

  Process {
    id: fetchProc
    property var job: null
    command: [Tools.curl, "-fsSL", "--max-time", "25", job ? job.url : ""]
    stdout: StdioCollector {
      onStreamFinished: {
        const j = fetchProc.job;
        const list = j ? Cal.parseNager(text) : null;
        if (list === null) {
          root.fetchNote = j ? "FAILED: " + j.code + " " + j.year : "";
        } else {
          const nager = Object.assign({}, root.holidayData.nager);
          nager[j.code] = Object.assign({}, nager[j.code] || {});
          nager[j.code][j.year] = list;
          root.holidayData = { nager: nager };
          holidaySave.restart();
          root.invalidate();
          root.fetchNote = "UPDATED " + j.code + " " + j.year;
        }
        pump.start();
      }
    }
  }

  // ---------------------------------------------------------------- moon and seasons
  function astroIndex(year) {
    const off = Clock.offsetSec;
    const key = year + "|" + off;
    const c = cache.astro;
    if (c[key])
      return c[key];
    const idx = {};
    const put = (ms, ev) => {
      const dn = Math.floor((ms + off * 1000) / 86400000);
      (idx[dn] = idx[dn] || []).push(ev);
    };
    for (const e of Cal.moonEvents(Date.UTC(year, 0, 1) - 3 * 86400000, Date.UTC(year + 1, 0, 1) + 3 * 86400000))
      put(e.ms, { type: "moon", kind: e.kind, ms: e.ms });
    for (const e of Cal.seasonEvents(year))
      put(e.ms, { type: "season", kind: e.kind, ms: e.ms });
    c[key] = idx;
    return idx;
  }

  function moonDay(dn) {
    const off = Clock.offsetSec;
    const key = dn + "|" + off;
    const c = cache.moon;
    if (c[key])
      return c[key];
    const p = Cal.moonCycle(dn * 86400000 + 43200000 - off * 1000);     // noon on that day
    const v = { glyph: Cal.moonGlyph(p), name: Cal.moonName(p), lit: Math.round(Cal.moonLit(p) * 100) };
    c[key] = v;
    return v;
  }

  function moonGlyph(dn) {
    const _r = rev;
    return moonDay(dn).glyph;
  }

  // ---------------------------------------------------------------- questions from the views
  // counts and flags for one day (the squares in the grid)
  function dayFlags(dn) {
    const _r = rev;
    const _c = cache;
    let e = 0, r = 0, h = 0, season = false, phase = "";
    if (settings.showEvents)
      for (const x of events)
        if (!hidden[x.id] && x.dn <= dn && dn <= x.dnEnd)
          e++;
    if (settings.showReminders)
      for (const x of reminders)
        if (!hidden[x.id] && x.dn <= dn && dn <= reminderEndDn(x))
          r++;
    const y = Cal.ymd(dn).y;
    if (settings.showHolidays) {
      const l = holidayIndex(y)[dn];
      h = l ? l.length : 0;
    }
    if (settings.showSeasons || settings.showMoon) {
      const a = astroIndex(y)[dn];
      if (a)
        for (const x of a) {
          if (x.type === "season" && settings.showSeasons)
            season = true;
          if (x.type === "moon" && settings.showMoon)
            phase = x.kind;
        }
    }
    return { h: h, e: e, r: r, season: season, phase: phase };
  }

  // totals over a range of days (the year and decade views)
  function countRange(dn0, dn1) {
    const _r = rev;
    const _c = cache;
    let e = 0, r = 0, h = 0;
    if (settings.showEvents)
      for (const x of events)
        if (!hidden[x.id] && x.dnEnd >= dn0 && x.dn <= dn1)
          e++;
    if (settings.showReminders)
      for (const x of reminders)
        if (!hidden[x.id] && reminderEndDn(x) >= dn0 && x.dn <= dn1)
          r++;
    if (settings.showHolidays)
      for (let y = Cal.ymd(dn0).y; y <= Cal.ymd(dn1).y; y++) {
        const idx = holidayIndex(y);
        for (const k in idx)
          if (+k >= dn0 && +k <= dn1)
            h += idx[k].length;
      }
    return { h: h, e: e, r: r };
  }

  // the list for one day
  function agenda(dn) {
    const _r = rev;
    const _c = cache;
    const off = Clock.offsetSec;
    const y = Cal.ymd(dn).y;
    const out = [];
    if (settings.showHolidays)
      for (const h of holidayIndex(y)[dn] || [])
        out.push({ kind: "holiday", order: 0, title: h.name, detail: h.src });
    for (const a of (settings.showSeasons || settings.showMoon) ? (astroIndex(y)[dn] || []) : []) {
      const mod = Math.floor((a.ms + off * 1000) / 60000) - dn * 1440;
      const when = Cal.clockText(mod);
      if (a.type === "season" && settings.showSeasons)
        out.push({ kind: "season", order: 1, startMin: mod, endMin: mod, title: Cal.seasonName(a.kind, true) + " BEGINS", detail: Cal.SEASON_EVENT_NAME[a.kind] + "  " + when });
      else if (a.type === "moon" && settings.showMoon)
        out.push({ kind: "phase", order: 2, startMin: mod, endMin: mod, glyph: Cal.moonGlyph(Cal.phaseCycle(a.kind)), title: Cal.phaseText(a.kind), detail: when });
    }
    if (settings.showMoon) {
      const m = moonDay(dn);
      out.push({ kind: "moon", order: 2.5, glyph: m.glyph, title: m.name, detail: m.lit + "% LIT" });
    }
    if (settings.showEvents)
      for (const x of events)
        if (!hidden[x.id] && x.dn <= dn && dn <= x.dnEnd) {
          const span = x.dnEnd - x.dn + 1;
          const mins = x.time === "" ? -1 : (+x.time.slice(0, 2)) * 60 + (+x.time.slice(3, 5));
          out.push({ kind: "event", order: mins < 0 ? 3 : 10 + mins / 1440, id: x.id, startMin: mins >= 0 && dn === x.dn ? mins : undefined, endMin: mins, title: x.title, detail: (x.time || "ALL DAY") + (span > 1 ? "  DAY " + (dn - x.dn + 1) + "/" + span : "") });
        }
    if (settings.showReminders)
      for (const x of reminders)
        if (!hidden[x.id] && x.dn <= dn && dn <= reminderEndDn(x)) {
          const start = x.dn * 1440 + x.minute;
          const end = start + x.length;
          const d0 = dn * 1440;
          let detail = Cal.clockText(x.minute);
          if (x.length > 0)
            detail = (start < d0 && end > d0 + 1440) ? "ALL DAY" : (start >= d0 ? Cal.clockText(x.minute) : "...") + "-" + (end <= d0 + 1440 ? Cal.clockText(end - d0) : "...");
          out.push({ kind: "reminder", order: 10 + (start >= d0 ? x.minute : 0) / 1440, id: x.id, startMin: Math.max(0, start - d0), endMin: Math.min(1440, end - d0), title: x.title, detail: detail, notify: x.notify, lengthText: Cal.lengthText(x.length) });
        }
    out.sort((a, b) => a.order - b.order);
    return out;
  }
}
