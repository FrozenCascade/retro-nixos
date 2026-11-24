.pragma library

// Parsers and small helpers for DisplayState (ddcutil output, schedule times).
// Plain functions with no QML in them, so they can be tried with node.

// ddcutil detect --brief -> { "HDMI-A-1": 5 }  (Hyprland's monitor name -> i2c bus number)
// Displays listed as "Invalid display" (no DDC/CI, or an HDMI splitter in the way) are left out.
function parseDdcDetect(text) {
  var out = {};
  text.split(/\n(?=Display |Invalid display|Phantom display)/).forEach(function (block) {
    if (!/^Display /.test(block))
      return;
    var bus = /I2C bus:\s+\/dev\/i2c-(\d+)/.exec(block);
    var con = /DRM[_ ]connector:\s+card\d+-(\S+)/.exec(block);
    if (bus && con)
      out[con[1]] = parseInt(bus[1]);
  });
  return out;
}

// ddcutil getvcp 10 --brief: "VCP 10 C 45 100" -> { cur: 45, max: 100 }
function parseVcp(text) {
  var m = /VCP\s+10\s+C\s+(\d+)\s+(\d+)/.exec(text);
  return m ? { cur: parseInt(m[1]), max: parseInt(m[2]) } : null;
}

// "20:30" -> 1230, anything else -> -1
function minutesOf(text) {
  var m = /^(\d{1,2}):(\d{2})$/.exec(String(text).trim());
  if (!m)
    return -1;
  var h = parseInt(m[1]);
  var min = parseInt(m[2]);
  return h > 23 || min > 59 ? -1 : h * 60 + min;
}

// is `now` (minutes since midnight) inside from..to? The window may cross midnight (20:00 -> 07:00).
function inWindow(now, from, to) {
  if (from < 0 || to < 0 || from === to)
    return false;
  return from < to ? (now >= from && now < to) : (now >= from || now < to);
}

if (typeof module !== "undefined")
  module.exports = { parseDdcDetect: parseDdcDetect, parseVcp: parseVcp, minutesOf: minutesOf, inWindow: inWindow };
