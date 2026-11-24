.pragma library

// Parsers for the commands NetState runs (nmcli, kdeconnect-cli, busctl, find).
// Plain functions with no QML in them, so they can be tried with node.

// nmcli -t separates fields with ":" and escapes a ":" or "\" inside a value with a backslash
function splitT(line) {
  var out = [];
  var cur = "";
  for (var i = 0; i < line.length; i++) {
    var c = line[i];
    if (c === "\\" && i + 1 < line.length) {
      cur += line[i + 1];
      i++;
    } else if (c === ":") {
      out.push(cur);
      cur = "";
    } else {
      cur += c;
    }
  }
  out.push(cur);
  return out;
}

// nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list
// -> [{ ssid, active, signal, secure }], one entry per name (the active or strongest access point)
function parseWifi(text) {
  var byName = {};
  text.split("\n").forEach(function (line) {
    if (line === "")
      return;
    var f = splitT(line);
    if (!f[1])
      return;
    var item = { ssid: f[1], active: f[0] === "yes", signal: parseInt(f[2]) || 0, secure: !!f[3] && f[3] !== "--" };
    var old = byName[item.ssid];
    if (!old || item.active || (!old.active && item.signal > old.signal))
      byName[item.ssid] = item;
  });
  return Object.keys(byName).map(function (k) { return byName[k]; });
}

// nmcli -t -f NAME,TYPE,ACTIVE,DEVICE connection show -> [{ name, type, active, device }]
function parseConnections(text) {
  var out = [];
  text.split("\n").forEach(function (line) {
    if (line === "")
      return;
    var f = splitT(line);
    out.push({ name: f[0], type: f[1], active: f[2] === "yes", device: f[3] || "" });
  });
  return out;
}

// kdeconnect-cli -l: "- Name: id (paired and reachable)"
function parseKdeList(text) {
  var out = [];
  text.split("\n").forEach(function (line) {
    var m = /^- (.+): ([0-9a-fA-F_]+) \((.*)\)$/.exec(line.trim());
    if (!m)
      return;
    out.push({
      name: m[1],
      id: m[2],
      paired: /\bpaired\b/.test(m[3]) && !/unpaired/.test(m[3]),
      reachable: /reachable/.test(m[3]) && !/unreachable/.test(m[3])
    });
  });
  return out;
}

// lines of "id type charge pairRequested" (a "-" where the value is missing) -> { id: { type, charge, pairRequested } }
function parseKdeProps(text) {
  var out = {};
  text.split("\n").forEach(function (line) {
    var f = line.trim().split(/\s+/);
    if (f.length < 3)
      return;
    var charge = parseInt(f[2]);
    out[f[0]] = { type: f[1] === "-" ? "" : f[1], charge: isNaN(charge) ? -1 : charge, pairRequested: f[3] === "true" };
  });
  return out;
}

// find -printf "%T@ %f\n" -> newest first: [{ time (seconds), name }]
function parseRecent(text) {
  var out = [];
  text.split("\n").forEach(function (line) {
    var m = /^(\d+)(?:\.\d+)? (.+)$/.exec(line);
    if (m)
      out.push({ time: parseInt(m[1]), name: m[2] });
  });
  return out.sort(function (a, b) { return b.time - a.time; });
}

// 90 -> "90S", 4000 -> "1H", 200000 -> "2D"
function ago(seconds) {
  if (seconds < 90)
    return Math.max(1, Math.round(seconds)) + "S";
  if (seconds < 5400)
    return Math.round(seconds / 60) + "M";
  if (seconds < 129600)
    return Math.round(seconds / 3600) + "H";
  return Math.round(seconds / 86400) + "D";
}

// Bluetooth icon name (as BlueZ reports it) -> the kind of glyph to show
function btKind(icon) {
  icon = String(icon || "");
  if (/headset|headphone/.test(icon)) return "headphones";
  if (/keyboard/.test(icon)) return "keyboard";
  if (/mouse/.test(icon)) return "mouse";
  if (/phone/.test(icon)) return "phone";
  if (/computer|laptop/.test(icon)) return "laptop";
  if (/speaker|audio-card/.test(icon)) return "speaker";
  if (/gaming|joystick/.test(icon)) return "gamepad";
  return "bluetooth";
}

if (typeof module !== "undefined")
  module.exports = { splitT: splitT, parseWifi: parseWifi, parseConnections: parseConnections, parseKdeList: parseKdeList, parseKdeProps: parseKdeProps, parseRecent: parseRecent, ago: ago, btKind: btKind };
