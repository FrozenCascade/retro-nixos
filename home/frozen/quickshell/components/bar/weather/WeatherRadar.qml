import Quickshell
import Quickshell.Io
import QtQuick
import qs

// The "Radar" tab: a dark map you can drag and zoom, with animated rain radar over it.
Item {
  id: radar

  // ---- settings ----
  // Radar frames: RainViewer's free API needs no key. To use your own LibreWXR server instead,
  // put its address here, for example "http://localhost:8080".
  readonly property string apiBase: "https://api.rainviewer.com"
  readonly property int colorScheme: 2            // 2 = Universal Blue
  readonly property string tileOptions: "1_1"     // smoothing, snow colors
  readonly property int minZoom: 2
  readonly property int maxZoom: 10               // how far in you can go
  readonly property int radarMaxZoom: 7           // RainViewer's free tier stops here; past it the radar is enlarged

  // Base map: the dark CARTO map. A free CARTO key saved in ~/.config/carto-basemaps.key is used when
  // there is one; without it the open tile address is used. (openstreetmap.org itself refuses requests
  // from programs that cannot send their own name, which Qt's Image cannot.)
  property string cartoKey: ""
  readonly property bool keyed: cartoKey !== ""

  FileView {
    path: Quickshell.env("HOME") + "/.config/carto-basemaps.key"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: radar.cartoKey = text().trim()
    onLoadFailed: radar.cartoKey = ""
  }

  property int zoom: 6
  property real u: 0.5          // map center, 0..1 across the world (west to east)
  property real v: 0.5          // map center, 0..1 down the world (north to south)

  property var frames: []
  property string host: ""
  property int frameIndex: 0
  property bool playing: true
  property bool failed: false

  // ---- temperature map ----
  // The button on the left cycles radar, temperature and rain forecast. RainViewer has neither of the last two,
  // so Open-Meteo is asked for the hourly temperature and rain at a small grid of points over the view, and the
  // colors blend between the points. Each ask costs one Open-Meteo call per point (a free daily allowance).
  property string mode: "rain"                  // "rain" (the radar), "temp" or "fcst" (rain forecast)
  readonly property var modes: ["rain", "temp", "fcst"]
  readonly property bool fcstMode: mode === "fcst"
  readonly property bool gridMode: mode !== "rain"       // a map made from the Open-Meteo grid
  readonly property string modeGlyph: mode === "temp" ? "\uf2c9" : (fcstMode ? "\uf0e9" : "\uf140")     // thermometer, umbrella, bullseye
  readonly property string modeTitle: mode === "temp" ? "TEMP" : (fcstMode ? "RAIN/HR" : "RADAR")

  function nextMode() {
    return modes[(modes.indexOf(mode) + 1) % modes.length];
  }

  readonly property int gridCols: 8             // edit here: more points look finer but use more of the allowance
  readonly property int gridRows: 6
  readonly property int gridRefreshMinutes: 15
  property var gridTemps: []                   // one list per hour, degrees C row by row, NaN where unknown
  property var gridTimes: []                    // each hour, in seconds since 1970
  property var gridRain: []                   // the same, for rain (mm in that hour)
  property real askedAt: 0                      // when the numbers arrived
  property int gridIndex: 0
  readonly property var gridFrames: fcstMode ? gridRain : gridTemps      // what the map shows
  readonly property var gridValues: gridFrames.length > 0 ? gridFrames[Math.min(gridIndex, gridFrames.length - 1)] : []
  readonly property int gridPastHours: 6        // edit here: how far back and ahead the temperature timeline runs
  readonly property int gridAheadHours: 18
  property bool gridFailed: false
  property var asked: ({})                      // the view of the ask in flight
  property real reqU: 0.5                       // the view the shown temperatures were asked for
  property real reqV: 0.5
  property int reqZoom: 6
  property real reqW: 0
  property real reqH: 0

  readonly property real tile: 256
  readonly property real world: tile * Math.pow(2, zoom)      // pixels across the whole world
  readonly property real cx: u * Math.pow(2, zoom)             // center, in tile units
  readonly property real cy: v * Math.pow(2, zoom)
  readonly property var frame: frames.length > 0 ? frames[Math.min(frameIndex, frames.length - 1)] : null

  // the play bar is shared: radar frames, or the hourly temperatures
  readonly property int count: gridMode ? gridTimes.length : frames.length
  readonly property int index: gridMode ? gridIndex : frameIndex
  readonly property real shownTime: gridMode ? (gridTimes.length > 0 ? gridTimes[Math.min(gridIndex, gridTimes.length - 1)] : 0) : (frame ? frame.time : 0)
  readonly property string shownLabel: {
    if (shownTime <= 0)
      return "--:--";
    const d = new Date(shownTime * 1000);
    return Qt.formatDateTime(d, d.toDateString() === new Date().toDateString() ? "HH:mm" : "ddd HH:mm");
  }

  function setIndex(i) {
    if (gridMode)
      gridIndex = i;
    else
      frameIndex = i;
  }

  // ---- map math ----
  function worldU(lon) {
    return (lon + 180) / 360;
  }

  function worldV(lat) {
    const r = lat * Math.PI / 180;
    return (1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2;
  }

  function recenter() {
    u = worldU(Weather.longitude);
    v = worldV(Weather.latitude);
  }

  function clampCenter() {
    u = ((u % 1) + 1) % 1;
    v = Math.max(0, Math.min(1, v));
  }

  // zoom in or out, keeping the point under (mx, my) where it is (the view center by default)
  function zoomAt(step, mx, my) {
    const nz = Math.max(minZoom, Math.min(maxZoom, zoom + step));

    if (nz === zoom)
      return;
    const px = mx === undefined ? view.width / 2 : mx;
    const py = my === undefined ? view.height / 2 : my;
    const before = tile * Math.pow(2, zoom);
    const after = tile * Math.pow(2, nz);

    const pu = u + (px - view.width / 2) / before;
    const pv = v + (py - view.height / 2) / before;

    u = pu - (px - view.width / 2) / after;
    v = pv - (py - view.height / 2) / after;
    zoom = nz;
    clampCenter();
  }

  function wrapX(x) {
    const n = Math.pow(2, zoom);
    return ((x % n) + n) % n;
  }

  function baseUrl(x, y) {
    const t = wrapX(x);

    if (keyed)
      return "https://basemaps.cartocdn.com/rastertiles/dark_all/" + zoom + "/" + t + "/" + y + ".png?key=" + cartoKey;

    // the open address spreads tiles over four hosts: a, b, c, d
    return "https://" + "abcd"[(t + y) % 4] + ".basemaps.cartocdn.com/dark_all/" + zoom + "/" + t + "/" + y + ".png";
  }

  // past the radar's own zoom limit, a radar tile covers several map tiles (and is enlarged)
  function radarUrl(x, y) {
    if (!frame)
      return "";

    const f = Math.pow(2, Math.max(0, zoom - radarMaxZoom));
    const z = Math.min(zoom, radarMaxZoom);

    return host + frame.path + "/256/" + z + "/" + Math.floor(wrapX(x) / f) + "/" + Math.floor(y / f) + "/" + colorScheme + "/" + tileOptions + ".png";
  }

  // ---- radar frame list ----
  Process {
    id: maps
    stdout: StdioCollector {
      onStreamFinished: radar.parseMaps(text)
    }
  }

  function load() {
    if (maps.running)
      return;
    maps.command = [Tools.curl, "-sS", "-m", "15", apiBase + "/public/weather-maps.json"];
    maps.running = true;
  }

  function parseMaps(text) {
    try {
      const d = JSON.parse(text);
      const past = d.radar.past || [];

      host = d.host;
      frames = past.concat(d.radar.nowcast || []);
      frameIndex = Math.max(0, past.length - 1);
      failed = false;
    } catch (e) {
      failed = true;
    }
  }

  // ---- temperature map: asking and colors ----
  function setMode(m) {
    mode = m;
    // the temperature and the rain forecast come from the same ask, so switching between them is free
    if (gridMode && (gridTemps.length === 0 || Date.now() - askedAt > gridRefreshMinutes * 60000))
      loadGrid();
  }

  // the point under the middle of each grid cell, in latitude and longitude
  function sampleGrid() {
    const lats = [];
    const lons = [];

    for (let j = 0; j < gridRows; j++) {
      for (let i = 0; i < gridCols; i++) {
        const uu = u + ((i + 0.5) / gridCols - 0.5) * view.width / world;
        const vv = Math.max(0.002, Math.min(0.998, v + ((j + 0.5) / gridRows - 0.5) * view.height / world));
        lons.push(((((uu % 1) + 1) % 1) * 360 - 180).toFixed(2));
        lats.push((Math.atan(Math.sinh(Math.PI * (1 - 2 * vv))) * 180 / Math.PI).toFixed(2));
      }
    }
    return { lats: lats, lons: lons };
  }

  function loadGrid() {
    if (!gridMode || view.width <= 0)
      return;
    if (gridProc.running) {
      gridWait.restart();
      return;
    }
    const g = sampleGrid();
    asked = { u: u, v: v, zoom: zoom, w: view.width, h: view.height };
    gridProc.command = [Tools.curl, "-sS", "-m", "15", "-G",
      "--data-urlencode", "latitude=" + g.lats.join(","),
      "--data-urlencode", "longitude=" + g.lons.join(","),
      "-d", "hourly=temperature_2m,precipitation", "-d", "past_hours=" + gridPastHours, "-d", "forecast_hours=" + gridAheadHours,
      "-d", "timeformat=unixtime", "https://api.open-meteo.com/v1/forecast"];
    gridProc.running = true;
  }

  function parseGrid(text) {
    try {
      const d = JSON.parse(text);
      const list = Array.isArray(d) ? d : [d];
      if (list.length !== gridCols * gridRows)
        throw new Error("wrong size");
      const times = list[0].hourly.time;
      const hourly = key => times.map((x, h) => list.map(p => {
          const v = p.hourly[key][h];
          return v === null || v === undefined ? NaN : Number(v);
        }));
      const first = gridTemps.length === 0;

      gridTemps = hourly("temperature_2m");
      gridRain = hourly("precipitation");
      gridTimes = times;
      askedAt = Date.now();
      if (first)          // start at the current hour
        gridIndex = Math.max(0, times.filter(x => x * 1000 <= Date.now()).length - 1);
      gridIndex = Math.min(gridIndex, times.length - 1);
      reqU = asked.u;
      reqV = asked.v;
      reqZoom = asked.zoom;
      reqW = asked.w;
      reqH = asked.h;
      gridFailed = false;
    } catch (e) {
      gridFailed = true;
    }
  }

  // panning and zooming ask again only once the view has really moved
  function viewMoved() {
    if (!gridMode)
      return;
    if (zoom !== reqZoom || Math.abs(u - reqU) * world > view.width * 0.25 || Math.abs(v - reqV) * world > view.height * 0.25)
      gridWait.restart();
  }

  onUChanged: viewMoved()
  onVChanged: viewMoved()
  onZoomChanged: viewMoved()

  Process {
    id: gridProc
    stdout: StdioCollector {
      onStreamFinished: radar.parseGrid(text)
    }
  }

  Timer {
    id: gridWait
    interval: 900
    onTriggered: radar.loadGrid()
  }

  Timer {
    interval: radar.gridRefreshMinutes * 60 * 1000
    running: radar.gridMode
    repeat: true
    onTriggered: radar.loadGrid()
  }

  // edit here: temperature (degrees C) and its color, blended between the stops
  readonly property var tempStops: [
    { t: -30, c: "#6a3d9a" }, { t: -15, c: "#3b5bdb" }, { t: -5, c: "#2c9bd6" }, { t: 5, c: "#2bb673" },
    { t: 15, c: "#d9d63a" }, { t: 25, c: "#f2a33a" }, { t: 35, c: "#e8452c" }, { t: 45, c: "#9e1b1b" }
  ]

  function tempColor(c) {
    const s = tempStops;

    if (!isFinite(c))
      return "transparent";
    if (c <= s[0].t)
      return s[0].c;
    for (let i = 1; i < s.length; i++) {
      if (c <= s[i].t) {
        const k = (c - s[i - 1].t) / (s[i].t - s[i - 1].t);
        const a = Qt.color(s[i - 1].c);
        const b = Qt.color(s[i].c);
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
      }
    }
    return s[s.length - 1].c;
  }

  // ---- rain forecast colors ----
  // edit here: mm of rain in an hour and its color, blended between the stops
  readonly property var rainForecastStops: [
    { v: 0.1, c: "#79c3e8" }, { v: 1, c: "#2f7fd0" }, { v: 3, c: "#e8d63a" }, { v: 7, c: "#f2903a" }, { v: 15, c: "#d6322a" }
  ]

  function blend(a, b, k) {
    const x = Qt.color(a);
    const y = Qt.color(b);

    return Qt.rgba(x.r + (y.r - x.r) * k, x.g + (y.g - x.g) * k, x.b + (y.b - x.b) * k, 1);
  }

  function rainColor(mm) {
    const s = rainForecastStops;

    if (!(mm >= 0.05))
      return "transparent";
    if (mm <= s[0].v)
      return s[0].c;
    for (let i = 1; i < s.length; i++) {
      if (mm <= s[i].v)
        return blend(s[i - 1].c, s[i].c, (mm - s[i - 1].v) / (s[i].v - s[i - 1].v));
    }
    return s[s.length - 1].c;
  }

  function cellColor(value) {
    return fcstMode ? rainColor(value) : tempColor(value);
  }

  function rainText(mm) {
    return Weather.imperial ? (mm / 25.4).toFixed(mm < 1 ? 3 : 2) + " in" : (mm < 1 ? mm.toFixed(1) : Math.round(mm)) + " mm";
  }

  // even spacing down the bar, the heaviest rain at the top
  function rainLegendStops() {
    const n = rainForecastStops.length;

    return rainForecastStops.map((s, i) => ({ p: 1 - i / (n - 1), c: s.c })).reverse();
  }

  function rainLegendTicks() {
    const n = rainForecastStops.length;

    return rainForecastStops.map((s, i) => ({ p: 1 - i / (n - 1), text: rainText(s.v) }));
  }

  // ---- the color key (MapLegend.qml): the top of the bar is the most, the bottom the least ----
  // edit here: the radar key only approximates RainViewer's colors
  readonly property var rainStops: [
    { p: 0, c: "#d6322a" }, { p: 0.25, c: "#f2903a" }, { p: 0.45, c: "#e8d63a" }, { p: 0.7, c: "#2f7fd0" }, { p: 1, c: "#79c3e8" }
  ]
  readonly property var rainTicks: [{ p: 0, text: "HEAVY" }, { p: 0.5, text: "MED" }, { p: 1, text: "LIGHT" }]
  readonly property var legendStops: fcstMode ? rainLegendStops() : (gridMode ? tempLegendStops() : rainStops)
  readonly property var legendTicks: fcstMode ? rainLegendTicks() : (gridMode ? tempLegendTicks() : rainTicks)

  function tempP(t) {
    const hot = tempStops[tempStops.length - 1].t;

    return (hot - t) / (hot - tempStops[0].t);
  }

  function tempLegendStops() {
    return tempStops.map(s => ({ p: tempP(s.t), c: s.c })).reverse();
  }

  function tempLegendTicks() {
    return tempStops.map(s => ({ p: tempP(s.t), text: degrees(s.t) }));
  }

  function degrees(c) {
    return Weather.imperial ? Math.round(c * 9 / 5 + 32) + "°F" : Math.round(c) + "°C";
  }

  Component.onCompleted: {
    recenter();
    load();
  }

  // changing the weather place moves the map there
  Connections {
    target: Weather

    function onLatitudeChanged() {
      radar.recenter();
    }
    function onLongitudeChanged() {
      radar.recenter();
    }
  }

  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    onTriggered: radar.load()
  }

  // animation
  Timer {
    interval: 1400
    running: radar.playing && radar.count > 1
    repeat: true
    onTriggered: radar.setIndex((radar.index + 1) % radar.count)
  }

  // ================= the map =================
  Rectangle {
    id: view
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      bottom: controls.top
      bottomMargin: 8
    }
    radius: 3
    color: Qt.rgba(0, 0, 0, 0.5)
    border.color: Theme.fgDim
    border.width: Retro.borderWidth
    clip: true

    // which tiles are visible
    readonly property int x0: Math.floor(radar.cx - width / 2 / radar.tile)
    readonly property int y0: Math.floor(radar.cy - height / 2 / radar.tile)
    readonly property int nx: Math.floor(radar.cx + width / 2 / radar.tile) - x0 + 1
    readonly property int ny: Math.floor(radar.cy + height / 2 / radar.tile) - y0 + 1

    Repeater {
      model: view.nx * view.ny

      Item {
        id: cell
        required property int index

        readonly property int tx: view.x0 + index % view.nx
        readonly property int ty: view.y0 + Math.floor(index / view.nx)
        readonly property bool valid: ty >= 0 && ty < Math.pow(2, radar.zoom)
        readonly property real f: Math.pow(2, Math.max(0, radar.zoom - radar.radarMaxZoom))
        readonly property real wx: radar.wrapX(tx)

        x: view.width / 2 + (tx - radar.cx) * radar.tile
        y: view.height / 2 + (ty - radar.cy) * radar.tile
        width: radar.tile
        height: radar.tile

        // the map
        Image {
          anchors.fill: parent
          asynchronous: true
          source: cell.valid ? radar.baseUrl(cell.tx, cell.ty) : ""
        }

        // the radar, enlarged when you zoom past its own limit
        Image {
          anchors.fill: parent
          asynchronous: true
          opacity: 0.85
          visible: !radar.gridMode
          source: cell.valid ? radar.radarUrl(cell.tx, cell.ty) : ""
          sourceClipRect: Qt.rect((cell.wx % cell.f) * radar.tile / cell.f, (((cell.ty % cell.f) + cell.f) % cell.f) * radar.tile / cell.f, radar.tile / cell.f, radar.tile / cell.f)
        }
      }
    }

    // temperature layer: one pixel per sample, blown up smoothly so the colors blend between points.
    // It stays on the spot of the map the samples were taken for, so it pans and zooms with the map.
    Item {
      id: tempLayer
      readonly property real s: radar.world / (radar.tile * Math.pow(2, radar.reqZoom))

      visible: radar.gridMode && radar.gridValues.length === radar.gridCols * radar.gridRows
      width: radar.reqW * s
      height: radar.reqH * s
      x: view.width / 2 + (radar.reqU - radar.u) * radar.world - width / 2
      y: view.height / 2 + (radar.reqV - radar.v) * radar.world - height / 2
      opacity: radar.fcstMode ? 0.85 : 0.6

      Item {
        width: radar.gridCols
        height: radar.gridRows
        layer.enabled: true
        layer.smooth: true
        transform: Scale {
          xScale: tempLayer.width / radar.gridCols
          yScale: tempLayer.height / radar.gridRows
        }

        Repeater {
          model: radar.gridCols * radar.gridRows

          Rectangle {
            required property int index

            x: index % radar.gridCols
            y: Math.floor(index / radar.gridCols)
            width: 1
            height: 1
            color: radar.cellColor(radar.gridValues[index])
          }
        }
      }
    }

    MapLegend {
      anchors {
        right: parent.right
        rightMargin: 8
        verticalCenter: parent.verticalCenter
      }
      stops: radar.legendStops
      ticks: radar.legendTicks
      title: radar.modeTitle
      labelWidth: radar.fcstMode ? 54 : (radar.gridMode ? 44 : 38)
    }

    // your location (stays on its exact spot while you move around)
    Text {
      x: (radar.worldU(Weather.longitude) - radar.u) * radar.world + view.width / 2 - width / 2
      y: (radar.worldV(Weather.latitude) - radar.v) * radar.world + view.height / 2 - height + 2
      text: "\uf041"
      color: Theme.red
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize + 8
    }

    // drag to pan, scroll wheel to zoom toward the cursor
    MouseArea {
      id: pan
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      preventStealing: true
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

      property real lastX: 0
      property real lastY: 0
      property real wheelAccum: 0

      onPressed: mouse => {
        lastX = mouse.x;
        lastY = mouse.y;
      }

      onPositionChanged: mouse => {
        if (!pressed)
          return;
        radar.u -= (mouse.x - lastX) / radar.world;
        radar.v -= (mouse.y - lastY) / radar.world;
        radar.clampCenter();

        lastX = mouse.x;
        lastY = mouse.y;
      }

      // one full wheel notch (120) is one zoom step; touchpads add up their small steps
      onWheel: wheel => {
        wheelAccum += wheel.angleDelta.y;

        if (Math.abs(wheelAccum) >= 120) {
          radar.zoomAt(wheelAccum > 0 ? 1 : -1, wheel.x, wheel.y);
          wheelAccum = 0;
        }
      }
    }

    // zoom and recenter buttons (declared after the drag area, so they get the clicks)
    Column {
      x: 8
      y: 8
      spacing: 4

      Repeater {
        model: [
          {
            label: "+",
            kind: "in"
          },
          {
            label: "-",
            kind: "out"
          },
          {
            label: "\uf05b",
            kind: "center"
          },      // crosshairs
          {
            label: "\uf2c9",
            kind: "mode"
          }      // thermometer; a drop while the temperatures show
        ]

        Rectangle {
          required property var modelData

          width: 26
          height: 26
          radius: 3
          color: Theme.bgAlt
          border.color: modelData.kind === "mode" && radar.gridMode ? Theme.orange : Theme.fg
          border.width: Retro.borderWidth

          Text {
            anchors.centerIn: parent
            text: parent.modelData.kind === "mode" ? radar.modeGlyph : parent.modelData.label
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: {
              if (parent.modelData.kind === "in")
                radar.zoomAt(1);
              else if (parent.modelData.kind === "out")
                radar.zoomAt(-1);
              else if (parent.modelData.kind === "mode")
                radar.setMode(radar.nextMode());
              else
                radar.recenter();
            }
          }
        }
      }
    }

    Text {
      visible: radar.gridMode && radar.gridFailed
      anchors.centerIn: parent
      text: "FORECAST DATA UNAVAILABLE (CHECK THE NETWORK)"
      color: Theme.red
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Text {
      visible: radar.failed && !radar.gridMode
      anchors.centerIn: parent
      text: "RADAR UNAVAILABLE (CHECK THE NETWORK)"
      color: Theme.red
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    // credits (RainViewer asks for a visible credit)
    Text {
      anchors {
        right: parent.right
        bottom: parent.bottom
        rightMargin: 6
        bottomMargin: 4
      }
      text: (radar.gridMode ? "Forecast data by Open-Meteo" : "Weather data by RainViewer") + "  ·  © OpenStreetMap contributors, © CARTO"
      color: creditMouse.containsMouse ? Theme.fg : Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 4

      MouseArea {
        id: creditMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["xdg-open", "https://www.rainviewer.com"])
      }
    }
  }

  // ================= controls: play, timeline, time =================
  Item {
    id: controls
    anchors {
      left: parent.left
      right: parent.right
      bottom: parent.bottom
    }
    height: 30

    Item {
      id: playButton
      width: 30
      height: 26
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        x: 2
        y: 2
        width: parent.width
        height: parent.height
        radius: 3
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: !playMouse.pressed
      }

      Rectangle {
        x: playMouse.pressed ? 2 : 0
        y: playMouse.pressed ? 2 : 0
        width: parent.width
        height: parent.height
        radius: 3
        color: Theme.bgAlt

        Text {
          anchors.centerIn: parent
          text: radar.playing ? "\uf04c" : "\uf04b"
          color: Theme.fg
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 1
        }
      }

      MouseArea {
        id: playMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: radar.playing = !radar.playing
      }
    }

    // timeline: click anywhere on it to jump to that frame
    Rectangle {
      id: track
      anchors {
        left: playButton.right
        right: timeLabel.left
        verticalCenter: parent.verticalCenter
      }
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      height: 8
      radius: 2
      color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2)

      Rectangle {
        width: 12
        height: 16
        radius: 3
        anchors.verticalCenter: parent.verticalCenter
        x: radar.count > 1 ? radar.index / (radar.count - 1) * (track.width - width) : 0
        color: Theme.orange
        border.color: Theme.fg
        border.width: Retro.borderWidth
      }

      MouseArea {
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
          if (radar.count < 2)
            return;
          radar.playing = false;
          radar.setIndex(Math.round(Math.max(0, Math.min(1, mouse.x / width)) * (radar.count - 1)));
        }
      }
    }

    Text {
      id: timeLabel
      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
      }
      width: 86
      horizontalAlignment: Text.AlignRight
      text: radar.shownLabel
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize
    }
  }
}
