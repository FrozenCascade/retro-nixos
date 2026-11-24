.pragma library

// Date, moon, season and holiday math for the calendar widget.
// No QML in here, so it can also be run and tested with plain node.
//
// A "day number" counts days from 1970-01-01, using UTC arithmetic so daylight saving can never
// shift a date. The widget works in day numbers everywhere and only turns them into text at the end.

var MONTHS = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"];
var MONTHS_SHORT = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
var DAYS_SHORT = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
var DAYS_LONG = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];

var MIN_YEAR = 1900;
var MAX_YEAR = 2199;

// ---------------------------------------------------------------- day numbers

function pad2(n) {
  return (n < 10 ? "0" : "") + n;
}

function pad4(n) {
  var s = String(n);
  while (s.length < 4)
    s = "0" + s;
  return s;
}

function dayNumber(y, m, d) {
  return Math.round(Date.UTC(y, m, d) / 86400000);
}

var MIN_DN = dayNumber(MIN_YEAR, 0, 1);
var MAX_DN = dayNumber(MAX_YEAR, 11, 31);

function clampDn(dn) {
  return Math.max(MIN_DN, Math.min(MAX_DN, dn));
}

// { y, m (0-11), d }
function ymd(dn) {
  var t = new Date(dn * 86400000);
  return { y: t.getUTCFullYear(), m: t.getUTCMonth(), d: t.getUTCDate() };
}

// 0 = Sunday
function weekday(dn) {
  return (((dn + 4) % 7) + 7) % 7;
}

function daysInMonth(y, m) {
  return dayNumber(m === 11 ? y + 1 : y, (m + 1) % 12, 1) - dayNumber(y, m, 1);
}

function keyOf(dn) {
  var t = ymd(dn);
  return pad4(t.y) + "-" + pad2(t.m + 1) + "-" + pad2(t.d);
}

function dnOfKey(key) {
  var p = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key));
  if (!p)
    return NaN;
  return dayNumber(+p[1], +p[2] - 1, +p[3]);
}

// the same day of the month n months later (cut to the end of a shorter month)
function addMonths(dn, n) {
  var t = ymd(dn);
  var idx = t.y * 12 + t.m + n;
  var y = Math.floor(idx / 12);
  var m = idx - y * 12;
  if (y < MIN_YEAR)
    return clampDn(dayNumber(MIN_YEAR, 0, 1));
  if (y > MAX_YEAR)
    return clampDn(dayNumber(MAX_YEAR, 11, 31));
  return dayNumber(y, m, Math.min(t.d, daysInMonth(y, m)));
}

function dayLabel(dn) {
  var t = ymd(dn);
  return DAYS_LONG[weekday(dn)] + ", " + t.d + " " + MONTHS[t.m] + " " + t.y;
}

// ---------------------------------------------------------------- the week list

function weekAnchor(mondayFirst) {
  var first = mondayFirst ? 1 : 0;
  return MIN_DN - ((weekday(MIN_DN) - first + 7) % 7);
}

function weekCount(mondayFirst) {
  return Math.floor((MAX_DN - weekAnchor(mondayFirst)) / 7) + 1;
}

function weekIndexOf(dn, mondayFirst) {
  return Math.floor((dn - weekAnchor(mondayFirst)) / 7);
}

// ---------------------------------------------------------------- text helpers

// minutes as "45m", "1h 30m", "2d 3h"
function lengthText(min) {
  min = Math.max(0, Math.round(min));
  if (min === 0)
    return "0m";
  var d = Math.floor(min / 1440);
  var h = Math.floor((min % 1440) / 60);
  var m = min % 60;
  if (d > 0)
    return d + "d" + (h > 0 ? " " + h + "h" : "") + (m > 0 && h === 0 ? " " + m + "m" : "");
  if (h > 0)
    return h + "h" + (m > 0 ? " " + pad2(m) + "m" : "");
  return m + "m";
}

// "90", "1h30", "1h 30m", "2d", "2d 3h", "45m" as minutes, or NaN when it makes no sense
function parseLength(text) {
  var s = String(text).trim().toLowerCase();
  if (s === "")
    return NaN;
  var re = /(\d+(?:\.\d+)?)\s*([dhm]?)/g;
  var m, total = 0, pos = 0, last = "", any = false;
  while ((m = re.exec(s)) !== null) {
    if (s.slice(pos, m.index).trim() !== "")
      return NaN;
    pos = re.lastIndex;
    var v = parseFloat(m[1]);
    var u = m[2] !== "" ? m[2] : (last === "d" ? "h" : "m");
    total += u === "d" ? v * 1440 : (u === "h" ? v * 60 : v);
    last = u;
    any = true;
  }
  if (!any || s.slice(pos).trim() !== "")
    return NaN;
  return Math.round(total);
}

// "HH:MM" of a count of minutes since midnight
function clockText(min) {
  min = ((Math.round(min) % 1440) + 1440) % 1440;
  return pad2(Math.floor(min / 60)) + ":" + pad2(min % 60);
}

// ---------------------------------------------------------------- moon (Meeus, Astronomical Algorithms ch. 49)

var D2R = Math.PI / 180;
var DELTA_T_DAYS = 69 / 86400;       // TT minus UT, about right for these years; far below one day

function sinD(x) {
  return Math.sin(x * D2R);
}

function cosD(x) {
  return Math.cos(x * D2R);
}

function jdToMs(jd) {
  return (jd - 2440587.5) * 86400000;
}

function msToJd(ms) {
  return ms / 86400000 + 2440587.5;
}

// Time (ms since 1970, UT) of a phase. k: a whole number is a new moon, then +.25 first quarter,
// +.5 full moon, +.75 last quarter.
function moonPhaseMs(k) {
  var T = k / 1236.85;
  var T2 = T * T, T3 = T2 * T, T4 = T3 * T;
  var jde = 2451550.09766 + 29.530588861 * k + 0.00015437 * T2 - 0.00000015 * T3 + 0.00000000073 * T4;
  var E = 1 - 0.002516 * T - 0.0000074 * T2;
  var M = 2.5534 + 29.10535670 * k - 0.0000014 * T2 - 0.00000011 * T3;
  var Mp = 201.5643 + 385.81693528 * k + 0.0107582 * T2 + 0.00001238 * T3 - 0.000000058 * T4;
  var F = 160.7108 + 390.67050284 * k - 0.0016118 * T2 - 0.00000227 * T3 + 0.000000011 * T4;
  var O = 124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3;
  var phase = Math.round((((k % 1) + 1) % 1) * 4) % 4;
  var c;

  if (phase === 0) {
    c = -0.40720 * sinD(Mp) + 0.17241 * E * sinD(M) + 0.01608 * sinD(2 * Mp) + 0.01039 * sinD(2 * F)
      + 0.00739 * E * sinD(Mp - M) - 0.00514 * E * sinD(Mp + M) + 0.00208 * E * E * sinD(2 * M)
      - 0.00111 * sinD(Mp - 2 * F) - 0.00057 * sinD(Mp + 2 * F) + 0.00056 * E * sinD(2 * Mp + M)
      - 0.00042 * sinD(3 * Mp) + 0.00042 * E * sinD(M + 2 * F) + 0.00038 * E * sinD(M - 2 * F)
      - 0.00024 * E * sinD(2 * Mp - M) - 0.00017 * sinD(O);
  } else if (phase === 2) {
    c = -0.40614 * sinD(Mp) + 0.17302 * E * sinD(M) + 0.01614 * sinD(2 * Mp) + 0.01043 * sinD(2 * F)
      + 0.00734 * E * sinD(Mp - M) - 0.00515 * E * sinD(Mp + M) + 0.00209 * E * E * sinD(2 * M)
      - 0.00111 * sinD(Mp - 2 * F) - 0.00057 * sinD(Mp + 2 * F) + 0.00056 * E * sinD(2 * Mp + M)
      - 0.00042 * sinD(3 * Mp) + 0.00042 * E * sinD(M + 2 * F) + 0.00038 * E * sinD(M - 2 * F)
      - 0.00024 * E * sinD(2 * Mp - M) - 0.00017 * sinD(O);
  } else {
    c = -0.62801 * sinD(Mp) + 0.17172 * E * sinD(M) - 0.01183 * E * sinD(Mp + M) + 0.00862 * sinD(2 * Mp)
      + 0.00804 * sinD(2 * F) + 0.00454 * E * sinD(Mp - M) + 0.00204 * E * E * sinD(2 * M)
      - 0.00180 * sinD(Mp - 2 * F) - 0.00070 * sinD(Mp + 2 * F) - 0.00040 * sinD(3 * Mp)
      - 0.00034 * E * sinD(2 * Mp - M) + 0.00032 * E * sinD(M + 2 * F) + 0.00032 * E * sinD(M - 2 * F)
      - 0.00028 * E * E * sinD(Mp + 2 * M) + 0.00027 * E * sinD(2 * Mp + M) - 0.00017 * sinD(O);
    var W = 0.00306 - 0.00038 * E * cosD(M) + 0.00026 * cosD(Mp) - 0.00002 * cosD(Mp - M)
      + 0.00002 * cosD(Mp + M) + 0.00002 * cosD(2 * F);
    c += phase === 1 ? W : -W;
  }

  return jdToMs(jde + c - DELTA_T_DAYS);
}

var PHASE_KINDS = ["new", "first", "full", "last"];

// every new / first quarter / full / last quarter between two times, oldest first: [{ kind, ms }]
function moonEvents(fromMs, toMs) {
  var k0 = Math.floor((msToJd(fromMs) - 2451550.09766) / 29.530588861) - 1;
  var k1 = Math.ceil((msToJd(toMs) - 2451550.09766) / 29.530588861) + 1;
  var out = [];
  for (var n = k0; n <= k1; n++) {
    for (var q = 0; q < 4; q++) {
      var ms = moonPhaseMs(n + q / 4);
      if (ms >= fromMs && ms <= toMs)
        out.push({ kind: PHASE_KINDS[q], ms: ms });
    }
  }
  return out;
}

// How far through the cycle the moon is at a time: 0 = new, 0.25 = first quarter, 0.5 = full,
// 0.75 = last quarter. It runs evenly between those four exact times, so it always agrees with them.
function moonCycle(ms) {
  var k = Math.floor((msToJd(ms) - 2451550.09766) / 29.530588861 * 4) / 4;
  var a = moonPhaseMs(k);
  var b = moonPhaseMs(k + 0.25);
  while (ms < a) {
    k -= 0.25;
    b = a;
    a = moonPhaseMs(k);
  }
  while (ms >= b) {
    k += 0.25;
    a = b;
    b = moonPhaseMs(k + 0.25);
  }
  var q = Math.round((((k % 1) + 1) % 1) * 4) % 4;
  return (q + (ms - a) / (b - a)) / 4;
}

function moonLit(cycle) {
  return (1 - Math.cos(2 * Math.PI * cycle)) / 2;
}

function moonName(p) {
  if (p < 0.0625 || p >= 0.9375) return "NEW MOON";
  if (p < 0.1875) return "WAXING CRESCENT";
  if (p < 0.3125) return "FIRST QUARTER";
  if (p < 0.4375) return "WAXING GIBBOUS";
  if (p < 0.5625) return "FULL MOON";
  if (p < 0.6875) return "WANING GIBBOUS";
  if (p < 0.8125) return "LAST QUARTER";
  return "WANING CRESCENT";
}

// a glyph from the Weather Icons font (the same set the weather window uses)
function moonGlyph(p) {
  var idx = Math.round(p * 28) % 28;
  return idx === 0 ? "\uf0eb" : String.fromCharCode(0xf0d0 + idx - 1);
}

function phaseCycle(kind) {
  return kind === "new" ? 0 : (kind === "first" ? 0.25 : (kind === "full" ? 0.5 : 0.75));
}

function phaseText(kind) {
  if (kind === "new") return "NEW MOON";
  if (kind === "first") return "FIRST QUARTER";
  if (kind === "full") return "FULL MOON";
  return "LAST QUARTER";
}

// ---------------------------------------------------------------- seasons (Meeus ch. 27)

var SEASON_TERMS = [
  [485, 324.96, 1934.136], [203, 337.23, 32964.467], [199, 342.08, 20.186], [182, 27.85, 445267.112],
  [156, 73.14, 45036.886], [136, 171.52, 22518.443], [77, 222.54, 65928.934], [74, 296.72, 3034.906],
  [70, 243.58, 9037.513], [58, 119.81, 33718.147], [52, 297.17, 150.678], [50, 21.02, 2281.226],
  [45, 247.54, 29929.562], [44, 325.15, 31555.956], [29, 60.93, 4443.417], [18, 155.12, 67555.328],
  [17, 288.79, 4562.452], [16, 198.04, 62894.029], [14, 199.76, 31436.921], [12, 95.39, 14577.848],
  [12, 287.11, 31931.756], [12, 320.81, 34777.259], [9, 227.73, 1222.114], [8, 15.45, 16859.074]
];

var SEASON_KINDS = ["march", "june", "sept", "dec"];

// k: 0 = March equinox, 1 = June solstice, 2 = September equinox, 3 = December solstice
function seasonMs(year, k) {
  var Y = (year - 2000) / 1000;
  var Y2 = Y * Y, Y3 = Y2 * Y, Y4 = Y3 * Y;
  var jde0;
  if (k === 0) jde0 = 2451623.80984 + 365242.37404 * Y + 0.05169 * Y2 - 0.00411 * Y3 - 0.00057 * Y4;
  else if (k === 1) jde0 = 2451716.56767 + 365241.62603 * Y + 0.00325 * Y2 + 0.00888 * Y3 - 0.00030 * Y4;
  else if (k === 2) jde0 = 2451810.21715 + 365242.01767 * Y - 0.11575 * Y2 + 0.00337 * Y3 + 0.00078 * Y4;
  else jde0 = 2451900.05952 + 365242.74049 * Y - 0.06223 * Y2 - 0.00823 * Y3 + 0.00032 * Y4;

  var T = (jde0 - 2451545.0) / 36525;
  var W = 35999.373 * T - 2.47;
  var dl = 1 + 0.0334 * cosD(W) + 0.0007 * cosD(2 * W);
  var S = 0;
  for (var i = 0; i < SEASON_TERMS.length; i++)
    S += SEASON_TERMS[i][0] * cosD(SEASON_TERMS[i][1] + SEASON_TERMS[i][2] * T);

  return jdToMs(jde0 + 0.00001 * S / dl - DELTA_T_DAYS);
}

// the four equinox / solstice times of a year: [{ kind, ms }]
function seasonEvents(year) {
  return SEASON_KINDS.map(function (kind, k) {
    return { kind: kind, ms: seasonMs(year, k) };
  });
}

var SEASON_NAME_NORTH = { march: "SPRING", june: "SUMMER", sept: "AUTUMN", dec: "WINTER" };
var SEASON_NAME_SOUTH = { march: "AUTUMN", june: "WINTER", sept: "SPRING", dec: "SUMMER" };
var SEASON_EVENT_NAME = { march: "MARCH EQUINOX", june: "JUNE SOLSTICE", sept: "SEPTEMBER EQUINOX", dec: "DECEMBER SOLSTICE" };

function seasonName(kind, northern) {
  return (northern === false ? SEASON_NAME_SOUTH : SEASON_NAME_NORTH)[kind];
}

// which season it is at a time: { name, kind, sinceMs, nextMs }
function seasonAt(ms, northern) {
  var y = new Date(ms).getUTCFullYear();
  var all = seasonEvents(y - 1).concat(seasonEvents(y), seasonEvents(y + 1));
  var cur = all[0];
  var next = all[1];
  for (var i = 0; i < all.length - 1; i++) {
    if (all[i].ms <= ms && ms < all[i + 1].ms) {
      cur = all[i];
      next = all[i + 1];
      break;
    }
  }
  return { name: seasonName(cur.kind, northern), kind: cur.kind, sinceMs: cur.ms, nextMs: next.ms };
}

// ---------------------------------------------------------------- holidays

// the n-th weekday (0 = Sunday) of a month, n = 1..5
function nthWeekday(y, m, wd, n) {
  var first = dayNumber(y, m, 1);
  return first + ((wd - weekday(first) + 7) % 7) + (n - 1) * 7;
}

function lastWeekday(y, m, wd) {
  var last = dayNumber(y, m, daysInMonth(y, m));
  return last - ((weekday(last) - wd + 7) % 7);
}

// Easter Sunday (Gregorian), the anonymous algorithm
function easterDn(y) {
  var a = y % 19;
  var b = Math.floor(y / 100);
  var c = y % 100;
  var d = Math.floor(b / 4);
  var e = b % 4;
  var f = Math.floor((b + 8) / 25);
  var g = Math.floor((b - f + 1) / 3);
  var h = (19 * a + b - d - g + 15) % 30;
  var i = Math.floor(c / 4);
  var k = c % 4;
  var l = (32 + 2 * e + 2 * i - h - k) % 7;
  var m = Math.floor((a + 11 * h + 22 * l) / 451);
  var month = Math.floor((h + l - 7 * m + 114) / 31);
  var day = ((h + l - 7 * m + 114) % 31) + 1;
  return dayNumber(y, month - 1, day);
}

// US federal holidays on their actual dates: [{ dn, name }]
function holidaysUS(y) {
  var out = [
    { dn: dayNumber(y, 0, 1), name: "New Year's Day" },
    { dn: nthWeekday(y, 0, 1, 3), name: "Martin Luther King Jr. Day" },
    { dn: nthWeekday(y, 1, 1, 3), name: "Presidents' Day" },
    { dn: lastWeekday(y, 4, 1), name: "Memorial Day" },
    { dn: dayNumber(y, 6, 4), name: "Independence Day" },
    { dn: nthWeekday(y, 8, 1, 1), name: "Labor Day" },
    { dn: nthWeekday(y, 9, 1, 2), name: "Columbus Day" },
    { dn: dayNumber(y, 10, 11), name: "Veterans Day" },
    { dn: nthWeekday(y, 10, 4, 4), name: "Thanksgiving Day" },
    { dn: dayNumber(y, 11, 25), name: "Christmas Day" }
  ];
  if (y >= 2021)
    out.push({ dn: dayNumber(y, 5, 19), name: "Juneteenth" });
  return out;
}

// well-known days that are not public holidays: [{ dn, name }]
function observancesUS(y) {
  var easter = easterDn(y);
  var out = [
    { dn: dayNumber(y, 1, 14), name: "Valentine's Day" },
    { dn: dayNumber(y, 2, 17), name: "St. Patrick's Day" },
    { dn: easter - 2, name: "Good Friday" },
    { dn: easter, name: "Easter Sunday" },
    { dn: nthWeekday(y, 4, 0, 2), name: "Mother's Day" },
    { dn: nthWeekday(y, 5, 0, 3), name: "Father's Day" },
    { dn: dayNumber(y, 9, 31), name: "Halloween" },
    { dn: dayNumber(y, 11, 24), name: "Christmas Eve" },
    { dn: dayNumber(y, 11, 31), name: "New Year's Eve" }
  ];
  if (y >= 2007) {
    out.push({ dn: nthWeekday(y, 2, 0, 2), name: "Daylight saving time begins" });
    out.push({ dn: nthWeekday(y, 10, 0, 1), name: "Daylight saving time ends" });
  }
  return out;
}

// ---------------------------------------------------------------- imported holiday data

// Nager.Date answer for one country and year: [{ dn, name }]
function parseNager(text) {
  var list;
  try {
    list = JSON.parse(text);
  } catch (e) {
    return null;
  }
  if (!Array.isArray(list))
    return null;
  var out = [];
  for (var i = 0; i < list.length; i++) {
    var dn = dnOfKey(list[i].date);
    var name = list[i].name || list[i].localName;
    if (!isNaN(dn) && name)
      out.push({ dn: dn, name: String(name) });
  }
  return out;
}

function icsText(v) {
  return String(v).replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1");
}

function icsDate(v) {
  var m = /^(\d{4})(\d{2})(\d{2})/.exec(v);
  return m ? dayNumber(+m[1], +m[2] - 1, +m[3]) : NaN;
}

// A small .ics reader: single events with a summary and a start day. All-day events that last
// several days are listed on each day. Repeat rules (RRULE) are not expanded.
function parseIcs(text) {
  var lines = String(text).replace(/\r\n?/g, "\n").replace(/\n[ \t]/g, "").split("\n");
  var out = [];
  var cur = null;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line === "BEGIN:VEVENT") {
      cur = { name: "", start: NaN, end: NaN, allDay: false };
      continue;
    }
    if (line === "END:VEVENT") {
      if (cur && cur.name !== "" && !isNaN(cur.start)) {
        var span = cur.allDay && !isNaN(cur.end) ? Math.max(1, Math.min(31, cur.end - cur.start)) : 1;
        for (var d = 0; d < span; d++)
          out.push({ dn: cur.start + d, name: cur.name });
      }
      cur = null;
      continue;
    }
    if (!cur)
      continue;
    var colon = line.indexOf(":");
    if (colon < 0)
      continue;
    var prop = line.slice(0, colon).split(";")[0].toUpperCase();
    var value = line.slice(colon + 1);
    if (prop === "SUMMARY") {
      cur.name = icsText(value);
    } else if (prop === "DTSTART") {
      cur.start = icsDate(value);
      cur.allDay = value.length === 8;
    } else if (prop === "DTEND") {
      cur.end = icsDate(value);
    }
  }
  return out;
}

// ---------------------------------------------------------------- time zone text

// "+0900" / "-0530" from `date +%z` as seconds east of UTC, or NaN
function parseOffset(text) {
  var m = /^([+-])(\d{2})(\d{2})/.exec(String(text).trim());
  if (!m)
    return NaN;
  return (m[1] === "-" ? -1 : 1) * (+m[2] * 3600 + +m[3] * 60);
}

function offsetText(sec) {
  var sign = sec < 0 ? "-" : "+";
  var a = Math.abs(sec);
  return "UTC" + sign + pad2(Math.floor(a / 3600)) + ":" + pad2(Math.floor((a % 3600) / 60));
}

// something that looks like an IANA zone name (Area/Place), so odd answers are never used
function looksLikeZone(s) {
  s = String(s).trim();
  return s === "UTC" || /^[A-Za-z]+(\/[A-Za-z0-9_+\-]+){1,2}$/.test(s);
}

if (typeof module !== "undefined")
  module.exports = { MONTHS, MONTHS_SHORT, DAYS_SHORT, DAYS_LONG, dayNumber, ymd, weekday, daysInMonth, keyOf, dnOfKey,
    addMonths, parseLength, weekAnchor, weekCount, weekIndexOf, lengthText, clockText, moonPhaseMs, moonEvents, moonCycle, moonLit,
    moonName, moonGlyph, phaseText, phaseCycle, seasonMs, seasonEvents, seasonAt, nthWeekday, lastWeekday, easterDn, holidaysUS, observancesUS,
    parseNager, parseIcs, parseOffset, offsetText, looksLikeZone, MIN_DN, MAX_DN, pad2, dayLabel };
