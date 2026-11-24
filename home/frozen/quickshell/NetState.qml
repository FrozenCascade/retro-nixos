pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import "lib/net.js" as Net

// Everything about connections in one place: Wi-Fi, Bluetooth, airplane mode, VPN and phones (KDE Connect).
// Wi-Fi and VPN go through nmcli, phones through kdeconnect-cli and busctl (exact paths come from Tools),
// Bluetooth through Quickshell.Bluetooth. The Connections window and the bar button only read from here.
Singleton {
  id: root

  // ---- settings (edit here) ----
  readonly property string receiveDir: Quickshell.env("HOME") + "/Downloads"     // where KDE Connect saves files from phones
  readonly property int scanSeconds: 20                                        // how long a Bluetooth scan runs

  property bool watching: false         // the Connections window is open: poll faster
  property bool ready: false            // false for the first seconds, so start-up changes make no sound

  // ================= Wi-Fi =================
  property bool wifiEnabled: false
  property var wifiNetworks: []         // { ssid, active, signal, secure }
  property var connections: []          // every saved connection: { name, type, active, device }
  property string wifiBusy: ""          // the network being connected right now
  property string wifiError: ""

  readonly property var wifiActive: wifiNetworks.find(n => n.active) || null
  readonly property string wifiSsid: wifiActive ? wifiActive.ssid : ""
  readonly property int wifiSignal: wifiActive ? wifiActive.signal : 0
  readonly property var savedWifi: connections.filter(c => c.type === "802-11-wireless").map(c => c.name)

  // four strength levels
  function wifiGlyph(signal) {
    return signal <= 25 ? Glyphs.wifi1 : (signal <= 50 ? Glyphs.wifi2 : (signal <= 75 ? Glyphs.wifi3 : Glyphs.wifi4));
  }

  readonly property string wifiBarGlyph: !wifiEnabled ? Glyphs.wifiOff : (wifiSsid === "" ? Glyphs.wifiNone : wifiGlyph(wifiSignal))

  function setWifi(on) {
    Quickshell.execDetached([Tools.nmcli, "radio", "wifi", on ? "on" : "off"]);
    wifiEnabled = on;
    settle.restart();
  }

  function rescan() {
    Quickshell.execDetached([Tools.nmcli, "device", "wifi", "rescan"]);
    afterScan.restart();
  }

  // a saved network reconnects by itself; a new secured one needs its password
  function wifiConnect(ssid, password) {
    if (connectProc.running)
      return;
    wifiBusy = ssid;
    wifiError = "";
    if (password)
      connectProc.command = [Tools.nmcli, "device", "wifi", "connect", ssid, "password", password];
    else if (savedWifi.indexOf(ssid) !== -1)
      connectProc.command = [Tools.nmcli, "connection", "up", "id", ssid];
    else
      connectProc.command = [Tools.nmcli, "device", "wifi", "connect", ssid];
    connectProc.running = true;
  }

  function wifiDisconnect() {
    const c = connections.find(x => x.type === "802-11-wireless" && x.active);
    if (c)
      Quickshell.execDetached([Tools.nmcli, "connection", "down", "id", c.name]);
    settle.restart();
  }

  function wifiForget(ssid) {
    Quickshell.execDetached([Tools.nmcli, "connection", "delete", "id", ssid]);
    settle.restart();
  }

  // ================= Bluetooth =================
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btPresent: btAdapter !== null
  readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false
  readonly property bool btScanning: btAdapter ? btAdapter.discovering : false
  readonly property var btDevices: btAdapter ? btAdapter.devices.values : []
  readonly property int btConnected: btDevices.filter(d => d.connected).length

  function setBt(on) {
    if (btAdapter)
      btAdapter.enabled = on;
  }

  function btScan(on) {
    if (!btAdapter)
      return;
    btAdapter.discovering = on;
    if (on)
      scanStop.restart();
  }

  // the battery as a percentage, or -1 when the device does not report one
  function btBattery(d) {
    if (!d.batteryAvailable)
      return -1;
    return Math.round(d.battery > 1 ? d.battery : d.battery * 100);
  }

  function btGlyph(d) {
    const kind = Net.btKind(d.icon);
    return Glyphs[kind] || Glyphs.bluetooth;
  }

  // ================= airplane mode =================
  // On = Wi-Fi and Bluetooth both off. What was on before is remembered and comes back when it ends.
  property var restore: ({ wifi: true, bt: true })
  readonly property bool airplane: !wifiEnabled && !btEnabled

  function setAirplane(on) {
    if (on) {
      if (!airplane) {
        restore = { wifi: wifiEnabled, bt: btEnabled };
        save();
      }
      setWifi(false);
      setBt(false);
    } else {
      setWifi(restore.wifi !== false);
      setBt(restore.bt !== false);
    }
  }

  // ================= VPN =================
  property string lastVpn: ""
  property string defaultVpn: ""        // the one the bar button's middle click connects to; set in the VPN tab
  property string vpnError: ""
  readonly property var vpns: connections.filter(c => c.type === "vpn" || c.type === "wireguard")
  readonly property var vpnActive: vpns.find(c => c.active) || null
  readonly property bool vpnUp: vpnActive !== null

  function isProton(name) {
    return /proton/i.test(name);
  }

  // the one a bare "connect" picks: the chosen default, else the last one used, else a Proton one, else the first saved
  function vpnDefault() {
    return vpns.find(c => c.name === defaultVpn) || vpns.find(c => c.name === lastVpn) || vpns.find(c => isProton(c.name)) || vpns[0] || null;
  }

  function vpnConnect(name) {
    lastVpn = name;
    save();
    Quickshell.execDetached([Tools.nmcli, "connection", "up", "id", name]);
    settle.restart();
  }

  function setDefaultVpn(name) {
    defaultVpn = defaultVpn === name ? "" : name;     // choosing it again clears the choice
    save();
  }

  function vpnForget(name) {
    Quickshell.execDetached([Tools.nmcli, "connection", "delete", "id", name]);
    if (defaultVpn === name)
      defaultVpn = "";
    save();
    settle.restart();
  }

  // Adds a WireGuard (.conf) or OpenVPN (.ovpn) file as a saved connection, without autoconnect.
  // NetworkManager names the connection after the file and a WireGuard name may be at most 15 characters,
  // so the name is cleaned and cut to fit.
  readonly property string importScript: [
    'nm=$1; f=$2; b=$(basename "$f"); n=${b%.*}; ext=${b##*.}',
    'case "$ext" in conf) t=wireguard ;; ovpn) t=openvpn ;; *) echo "ONLY .CONF OR .OVPN FILES" >&2; exit 2 ;; esac',
    'short=$(printf %s "$n" | tr -c "A-Za-z0-9_-" "-" | cut -c1-15)',
    'd=$(mktemp -d); cp "$f" "$d/$short.$ext"',
    '"$nm" connection import type "$t" file "$d/$short.$ext" >/dev/null && "$nm" connection modify id "$short" connection.autoconnect no',
    'r=$?; rm -rf "$d"; exit $r'
  ].join("\n")

  function vpnImport(urls) {
    const paths = Array.from(urls).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")));
    if (paths.length === 0 || importProc.running)
      return;
    vpnError = "";
    importQueue = paths.slice(1);
    importProc.command = ["sh", "-c", importScript, "sh", Tools.nmcli, paths[0]];
    importProc.running = true;
  }

  property var importQueue: []

  Process {
    id: importProc
    stderr: StdioCollector {
      id: importErr
    }
    onExited: code => {
      if (code !== 0)
        root.vpnError = (importErr.text.trim().split("\n")[0] || "IMPORT FAILED").toUpperCase();
      root.refresh();
      if (root.importQueue.length > 0) {
        const next = root.importQueue[0];
        root.importQueue = root.importQueue.slice(1);
        importProc.command = ["sh", "-c", root.importScript, "sh", Tools.nmcli, next];
        importProc.running = true;
      }
    }
  }

  function vpnDisconnect() {
    if (vpnActive)
      Quickshell.execDetached([Tools.nmcli, "connection", "down", "id", vpnActive.name]);
    settle.restart();
  }

  function vpnToggle() {
    if (vpnUp) {
      vpnDisconnect();
    } else {
      const c = vpnDefault();
      if (c)
        vpnConnect(c.name);
    }
  }

  // ================= what the bar button shows =================
  // Priority: airplane, then VPN, then Wi-Fi
  readonly property string barGlyph: airplane ? Glyphs.airplane : (vpnUp ? Glyphs.vpn : wifiBarGlyph)
  readonly property color barTint: airplane ? Theme.orange : (vpnUp ? Theme.green : (wifiSsid === "" ? Theme.fgDim : Theme.fg))

  // ================= phones (KDE Connect) =================
  property var phones: []               // { id, name, paired, reachable, type, charge, pairRequested }
  property var phoneIds: []             // only changes when a phone appears or goes; the list rows follow this, so they do not flicker
  property string phoneId: ""           // the phone that file drops go to
  property var received: []             // files that arrived lately: { time, name }

  readonly property var phone: phoneById(phoneId)

  function phoneById(id) {
    return phones.find(p => p.id === id) || null;
  }

  // changes nothing (and so redraws nothing) when the new list is the same as the old one
  function setPhones(list) {
    if (JSON.stringify(list) === JSON.stringify(phones))
      return;
    phones = list;
    const ids = list.map(p => p.id);
    if (JSON.stringify(ids) !== JSON.stringify(phoneIds))
      phoneIds = ids;
  }

  function refreshPhones() {
    if (!kdeProc.running)
      kdeProc.running = true;
    if (!recentProc.running)
      recentProc.running = true;
  }

  function phoneDo(id, flag) {
    Quickshell.execDetached([Tools.kdeconnectCli, "-d", id, flag]);
    phonesSoon.restart();
  }

  function phoneShareText(id, text) {
    if (text.trim() !== "")
      Quickshell.execDetached([Tools.kdeconnectCli, "-d", id, "--share-text", text.trim()]);
  }

  function phoneSms(id, number, text) {
    if (number.trim() !== "" && text.trim() !== "")
      Quickshell.execDetached([Tools.kdeconnectCli, "-d", id, "--send-sms", text.trim(), "--destination", number.trim()]);
  }

  // answer a pairing request that came from the phone
  function phonePairAnswer(id, accept) {
    Quickshell.execDetached([Tools.busctl, "--user", "call", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + id, "org.kde.kdeconnect.device", accept ? "acceptPairing" : "cancelPairing"]);
    phonesSoon.restart();
  }

  // mounts the phone's storage (needs sshfs) and opens it in the file manager
  readonly property string mountScript: [
    'b=$1; id=$2; p=/modules/kdeconnect/devices/$id/sftp; i=org.kde.kdeconnect.device.sftp',
    '"$b" --user call org.kde.kdeconnect $p $i mountAndWait >/dev/null 2>&1',
    'mp=$("$b" --user get-property org.kde.kdeconnect $p $i mountPoint 2>/dev/null | cut -d\'"\' -f2)',
    '[ -n "$mp" ] && exec uwsm app -- xdg-open "$mp"'
  ].join("\n")

  function phoneFiles(id) {
    Quickshell.execDetached(["sh", "-c", mountScript, "sh", Tools.busctl, id]);
  }

  // send every dropped file to a phone, one at a time
  function sendFiles(id, urls) {
    const paths = Array.from(urls).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")));
    if (id === "" || paths.length === 0)
      return;
    Quickshell.execDetached(["sh", "-c", 'k=$1; id=$2; shift 2; for f; do "$k" -d "$id" --share "$f"; done', "sh", Tools.kdeconnectCli, id].concat(paths));
  }

  function fixSelection() {
    if (phones.some(p => p.id === phoneId))
      return;
    const first = phones.find(p => p.paired && p.reachable) || phones[0];
    phoneId = first ? first.id : "";
  }

  // asks the KDE Connect daemon for each phone's kind and battery
  readonly property string propsScript: [
    'b=$1; shift',
    'for id in "$@"; do',
    '  t=$("$b" --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$id org.kde.kdeconnect.device type 2>/dev/null | cut -d\'"\' -f2)',
    '  c=$("$b" --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$id/battery org.kde.kdeconnect.device.battery charge 2>/dev/null | cut -d" " -f2)',
    '  r=$("$b" --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$id org.kde.kdeconnect.device isPairRequestedByPeer 2>/dev/null | cut -d" " -f2)',
    '  echo "$id ${t:--} ${c:--} ${r:--}"',
    'done'
  ].join("\n")

  // ================= refreshing =================
  // anything a command prints on its error output goes to the log:  qs log
  function complain(what, text) {
    if (text.trim() !== "")
      console.warn("NetState " + what + ": " + text.trim());
  }

  function refresh() {
    if (!radioProc.running)
      radioProc.running = true;
    if (!wifiProc.running)
      wifiProc.running = true;
    if (!connProc.running)
      connProc.running = true;
  }

  Process {
    id: radioProc
    stderr: StdioCollector { onStreamFinished: root.complain("radioProc", text) }
    command: [Tools.nmcli, "radio", "wifi"]
    stdout: StdioCollector {
      onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
    }
  }

  Process {
    id: wifiProc
    stderr: StdioCollector { onStreamFinished: root.complain("wifiProc", text) }
    command: [Tools.nmcli, "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"]
    stdout: StdioCollector {
      onStreamFinished: root.wifiNetworks = Net.parseWifi(text)
    }
  }

  Process {
    id: connProc
    stderr: StdioCollector { onStreamFinished: root.complain("connProc", text) }
    command: [Tools.nmcli, "-t", "-f", "NAME,TYPE,ACTIVE,DEVICE", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: root.connections = Net.parseConnections(text)
    }
  }

  Process {
    id: connectProc
    stderr: StdioCollector {
      id: connectErr
    }
    onExited: code => {
      root.wifiBusy = "";
      root.wifiError = code === 0 ? "" : connectErr.text.trim().split("\n")[0].toUpperCase();
      root.refresh();
    }
  }

  Process {
    id: kdeProc
    command: [Tools.kdeconnectCli, "-l"]
    stdout: StdioCollector {
      onStreamFinished: {
        const old = {};
        root.phones.forEach(p => old[p.id] = p);
        if (text.trim() === "")
          return;                                   // the daemon did not answer: keep what is shown
        const list = Net.parseKdeList(text);
        list.forEach(p => {
          p.type = old[p.id] ? old[p.id].type : "";
          p.charge = old[p.id] ? old[p.id].charge : -1;
          p.pairRequested = old[p.id] ? old[p.id].pairRequested : false;
        });
        root.setPhones(list);
        root.fixSelection();

        const ids = list.filter(p => p.reachable).map(p => p.id);
        if (ids.length > 0 && !propsProc.running) {
          propsProc.command = ["sh", "-c", root.propsScript, "sh", Tools.busctl].concat(ids);
          propsProc.running = true;
        }
      }
    }
  }

  Process {
    id: propsProc
    stdout: StdioCollector {
      onStreamFinished: {
        const props = Net.parseKdeProps(text);
        root.setPhones(root.phones.map(p => props[p.id] ? Object.assign({}, p, props[p.id]) : p));
      }
    }
  }

  Process {
    id: recentProc
    command: ["find", root.receiveDir, "-maxdepth", "1", "-type", "f", "-mmin", "-1440", "-printf", "%T@ %f\\n"]
    stdout: StdioCollector {
      onStreamFinished: root.received = Net.parseRecent(text).slice(0, 5)
    }
  }

  // NetworkManager reports every change; refresh a moment after the last one
  Process {
    running: true
    command: [Tools.nmcli, "monitor"]
    stdout: SplitParser {
      onRead: settle.restart()
    }
  }

  Timer {
    id: settle
    interval: 500
    onTriggered: root.refresh()
  }

  Timer {
    id: afterScan
    interval: 2500
    onTriggered: root.refresh()
  }

  Timer {
    id: phonesSoon
    interval: 1200
    onTriggered: root.refreshPhones()
  }

  // signal strength changes without any event, so there is a slow poll (a fast one while the window is open)
  Timer {
    interval: root.watching ? 4000 : 30000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    id: scanStop
    interval: root.scanSeconds * 1000
    onTriggered: root.btScan(false)
  }

  // ================= sounds =================
  property int btSeen: 0

  onWifiSsidChanged: {
    if (ready)
      Sounds.play(wifiSsid !== "" ? "network-connectivity-established" : "network-connectivity-lost");
  }

  onBtConnectedChanged: {
    if (ready)
      Sounds.play(btConnected > btSeen ? "device-added" : "device-removed");
    btSeen = btConnected;
  }

  Timer {
    interval: 4000
    running: true
    onTriggered: {
      root.btSeen = root.btConnected;
      root.ready = true;
    }
  }

  // ================= remembered between runs =================
  function save() {
    prefs.setText(JSON.stringify({ restore: restore, lastVpn: lastVpn, defaultVpn: defaultVpn }));
  }

  FileView {
    id: prefs
    path: Quickshell.statePath("net.json")
    onLoaded: {
      try {
        const d = JSON.parse(prefs.text());
        if (d.restore)
          root.restore = d.restore;
        root.lastVpn = d.lastVpn || "";
        root.defaultVpn = d.defaultVpn || "";
      } catch (e) {}
    }
  }

  Component.onCompleted: refresh()
}
