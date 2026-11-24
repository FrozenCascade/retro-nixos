pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Weather data and settings for the bar button and the weather popup.
// Forecast, air quality and place search: Open-Meteo. Alerts: US National Weather Service.
Singleton {
  id: root

  // ================= saved settings =================
  FileView {
    id: settingsFile
    path: Quickshell.statePath("weather-settings.json")
    // Written at once. Choosing a place changes name, latitude and longitude one after another; with the
    // slower write plus a reload of the file, the reload could bring back an old longitude.
    blockWrites: true
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
        writeAdapter();
    }

    JsonAdapter {
      id: saved
      property string name: "New York, NY"          // the place before you choose one
      property real latitude: 40.7128
      property real longitude: -74.0060
      property string units: "imperial"       // "imperial" (°F, mph) or "metric" (°C, km/h)
      property list<string> places: []        // saved places, each "Name|latitude|longitude"
      property bool hidden: false             // middle click on the weather button hides the weather everywhere
    }
  }

  readonly property string locationName: saved.name
  readonly property real latitude: saved.latitude
  readonly property real longitude: saved.longitude
  readonly property bool imperial: saved.units !== "metric"
  readonly property bool hidden: saved.hidden

  readonly property var places: Array.from(saved.places).map(p => {
    const s = String(p).split("|");
    return {
      name: s[0],
      latitude: parseFloat(s[1]),
      longitude: parseFloat(s[2])
    };
  })

  function setLocation(name, lat, lon) {
    saved.name = name;
    saved.latitude = lat;
    saved.longitude = lon;
  }

  function addPlace(name, lat, lon) {
    const entry = name + "|" + lat + "|" + lon;
    const list = Array.from(saved.places);

    if (list.indexOf(entry) < 0)
      list.push(entry);

    saved.places = list;
  }

  function removePlace(index) {
    const list = Array.from(saved.places);
    list.splice(index, 1);
    saved.places = list;
  }

  // pick a search result: go there and remember it
  function chooseResult(r) {
    const name = r.detail ? r.name + ", " + r.detail : r.name;
    setLocation(name, r.latitude, r.longitude);
    addPlace(name, r.latitude, r.longitude);
  }

  function toggleUnits() {
    saved.units = imperial ? "metric" : "imperial";
  }

  // middle click on the weather button: hide the weather everywhere, or show it again
  function toggleHidden() {
    saved.hidden = !saved.hidden;
  }

  // ================= units =================
  readonly property string tempUnit: imperial ? "°F" : "°C"
  readonly property string speedUnit: imperial ? "mph" : "km/h"
  readonly property string precipUnit: imperial ? "in" : "mm"

  function fmt(v, digits) {
    if (v === null || v === undefined || isNaN(v))
      return "--";

    return Number(v).toFixed(digits === undefined ? 0 : digits);
  }

  // ================= current conditions =================
  property bool loaded: false
  property bool failed: false
  property real temperature: 0
  property real feelsLike: 0
  property int humidity: 0
  property var dewPoint: null
  property var pressure: null          // hPa
  property real windSpeed: 0
  property real windDir: 0
  property var precipNow: null
  property int weatherCode: -1         // WMO code
  property bool isDay: true
  property var visibility: null        // meters
  property int cloudCover: 0
  property var uvIndex: null
  property var snowDepth: null         // meters (feet when imperial)
  property real utcOffset: -new Date().getTimezoneOffset() * 60   // the location's offset from UTC, seconds
  property var hourly: []              // next 24 hours
  property var daily: []               // 8 days, today first
  property string updated: ""

  readonly property string tempText: loaded ? Math.round(temperature) + tempUnit : "--" + tempUnit
  readonly property string glyph: loaded ? iconFor(weatherCode, isDay) : "\uf07b"
  readonly property string description: loaded ? describe(weatherCode) : ""
  readonly property real high: daily.length > 0 ? daily[0].max : 0
  readonly property real low: daily.length > 0 ? daily[0].min : 0
  readonly property real precipToday: daily.length > 0 ? daily[0].rain : 0

  function compass(deg) {
    return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(deg / 45) % 8];
  }

  readonly property string windText: loaded ? compass(windDir) + " " + Math.round(windSpeed) + " " + speedUnit : "--"

  readonly property string pressureText: {
    if (!loaded || pressure === null)
      return "--";

    return imperial ? (pressure * 0.02953).toFixed(2) + " inHg" : Math.round(pressure) + " hPa";
  }

  readonly property string visibilityText: {
    if (!loaded || visibility === null || visibility === undefined)
      return "--";

    return imperial ? (visibility / 1609.34).toFixed(1) + " mi" : (visibility / 1000).toFixed(1) + " km";
  }

  readonly property string uvText: {
    if (!loaded || uvIndex === null || uvIndex === undefined)
      return "--";

    const label = uvIndex < 3 ? "LOW" : uvIndex < 6 ? "MODERATE" : uvIndex < 8 ? "HIGH" : uvIndex < 11 ? "VERY HIGH" : "EXTREME";

    return uvIndex.toFixed(1) + " (" + label + ")";
  }

  readonly property string snowText: {
    if (!loaded || snowDepth === null || snowDepth === undefined)
      return "--";

    return imperial ? (snowDepth * 12).toFixed(1) + " in" : (snowDepth * 100).toFixed(1) + " cm";
  }

  // ================= air quality, pollen, alerts =================
  property bool airLoaded: false
  property var aqi: 0
  property var pm25: null
  property var pm10: null
  property var no2: null
  property var o3: null
  property var pollen: []              // [{ name, value }]
  property var alerts: []              // [{ event, severity, headline }]

  readonly property bool hasPollen: pollen.some(p => p.value !== null && p.value !== undefined)

  readonly property string aqiLabel: aqi <= 50 ? "GOOD" : aqi <= 100 ? "MODERATE" : aqi <= 150 ? "UNHEALTHY FOR SENSITIVE" : aqi <= 200 ? "UNHEALTHY" : aqi <= 300 ? "VERY UNHEALTHY" : "HAZARDOUS"

  readonly property color aqiColor: aqi <= 50 ? Theme.green : aqi <= 100 ? Theme.yellow : aqi <= 150 ? Theme.orange : Theme.red

  function pollenLevel(v) {
    return v < 10 ? "LOW" : v < 50 ? "MODERATE" : "HIGH";
  }

  // ================= time, sun and moon =================
  property real nowMs: Date.now()

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  readonly property real locNowMs: nowMs + utcOffset * 1000

  readonly property string localTimeText: {
    const d = new Date(locNowMs);
    const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

    return days[d.getUTCDay()] + " " + String(d.getUTCDate()).padStart(2, "0") + " " + months[d.getUTCMonth()] + "  " + String(d.getUTCHours()).padStart(2, "0") + ":" + String(d.getUTCMinutes()).padStart(2, "0");
  }

  // "2026-10-24T07:10" (the location's wall clock) as milliseconds on the same shifted scale as locNowMs
  function wallMs(s) {
    return Date.parse(s + ":00Z");
  }

  function span(ms) {
    const m = Math.max(0, Math.floor(ms / 60000));
    return Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m";
  }

  readonly property real sunriseMs: daily.length > 0 ? wallMs(daily[0].sunrise) : 0
  readonly property real sunsetMs: daily.length > 0 ? wallMs(daily[0].sunset) : 0
  readonly property real sunProgress: sunsetMs > sunriseMs ? (locNowMs - sunriseMs) / (sunsetMs - sunriseMs) : -1
  readonly property bool sunUp: sunProgress >= 0 && sunProgress <= 1
  readonly property string sunriseText: daily.length > 0 ? daily[0].sunrise.slice(11, 16) : "--:--"
  readonly property string sunsetText: daily.length > 0 ? daily[0].sunset.slice(11, 16) : "--:--"
  readonly property string dayLengthText: sunsetMs > sunriseMs ? span(sunsetMs - sunriseMs) : "--"
  readonly property string sunLeftText: sunUp ? span(sunsetMs - locNowMs) : ""

  // moon phase from the date alone (0 = new moon, 0.5 = full moon)
  readonly property real moonPhase: {
    const days = nowMs / 86400000 + 2440587.5 - 2451550.1;
    const p = (days / 29.530588853) % 1;
    return p < 0 ? p + 1 : p;
  }

  readonly property real moonIllumination: (1 - Math.cos(2 * Math.PI * moonPhase)) / 2

  readonly property string moonName: {
    const p = moonPhase;

    if (p < 0.03 || p > 0.97)
      return "New Moon";
    if (p < 0.22)
      return "Waxing Crescent";
    if (p < 0.28)
      return "First Quarter";
    if (p < 0.47)
      return "Waxing Gibbous";
    if (p < 0.53)
      return "Full Moon";
    if (p < 0.72)
      return "Waning Gibbous";
    if (p < 0.78)
      return "Last Quarter";
    return "Waning Crescent";
  }

  readonly property string moonGlyph: {
    const idx = Math.round(moonPhase * 28) % 28;
    return idx === 0 ? "\uf0eb" : String.fromCharCode(0xf0d0 + idx - 1);
  }

  function dayName(i, date) {
    if (i === 0)
      return "TODAY";
    if (i === 1)
      return "TOMORROW";

    const names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    return names[new Date(date + "T12:00:00Z").getUTCDay()] + " " + date.slice(8, 10);
  }

  // ================= fetching =================
  Process {
    id: fetchWeather
    stdout: StdioCollector {
      onStreamFinished: root.parseWeather(text)
    }
  }

  Process {
    id: fetchAir
    stdout: StdioCollector {
      onStreamFinished: root.parseAir(text)
    }
  }

  // Alert IDs already announced during this lifetime of the singleton.
  // Keep these even when an alert disappears from a later API response,
  // so temporary API inconsistencies do not produce duplicate popups.
  property var announcedAlertIds: ({})

  // Prevent repeated requests when settings change or refresh() is called.
  property real lastAlertRequestMs: 0

  readonly property string alertLocationKey: latitude.toFixed(4) + "," + longitude.toFixed(4)

  Process {
    id: fetchAlerts

    // Remember which location this particular request belongs to.
    property string requestLocationKey: ""
    property string requestLocationName: ""

    stdout: StdioCollector {
      onStreamFinished: root.parseAlerts(text, fetchAlerts.requestLocationKey, fetchAlerts.requestLocationName)
    }
  }

  function refreshAlerts() {
    if (fetchAlerts.running)
      return;
    const now = Date.now();

    // Never make requests less than 30 seconds apart.
    if (now - lastAlertRequestMs < 30000)
      return;
    lastAlertRequestMs = now;
    fetchAlerts.requestLocationKey = alertLocationKey;
    fetchAlerts.requestLocationName = locationName;

    fetchAlerts.command = [Tools.curl, "-f", "-sS", "-m", "15", "-H", "User-Agent: quickshell-weather", "-H", "Accept: application/geo+json", "https://api.weather.gov/alerts/active?point=" + alertLocationKey];

    fetchAlerts.running = true;
  }

  // Poll alerts independently of the 15-minute weather refresh.
  Timer {
    interval: 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshAlerts()
  }

  function refresh() {
    if (fetchWeather.running || fetchAir.running) {
      retryTimer.restart();
      return;
    }

    const where = "?latitude=" + latitude + "&longitude=" + longitude;

    const unitArgs = imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch" : "&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm";

    fetchWeather.command = [Tools.curl, "-sS", "-m", "15", "https://api.open-meteo.com/v1/forecast" + where + unitArgs + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,is_day," + "precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m" + "&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,is_day," + "visibility,uv_index,snow_depth" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset," + "precipitation_sum,precipitation_probability_max" + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,is_day," + "precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m,cloud_cover" + "&forecast_days=8&timezone=auto"];
    fetchWeather.running = true;

    fetchAir.command = [Tools.curl, "-sS", "-m", "15", "https://air-quality-api.open-meteo.com/v1/air-quality" + where + "&current=us_aqi,pm10,pm2_5,nitrogen_dioxide,ozone,alder_pollen,birch_pollen,grass_pollen" + "&timezone=auto"];
    fetchAir.running = true;

    root.refreshAlerts();
  }

  function parseWeather(text) {
    try {
      const d = JSON.parse(text);
      const c = d.current;

      if (!c)
        throw new Error("no data");

      utcOffset = d.utc_offset_seconds || 0;
      temperature = c.temperature_2m;
      feelsLike = c.apparent_temperature;
      humidity = Math.round(c.relative_humidity_2m);
      cloudCover = Math.round(c.cloud_cover);
      dewPoint = c.dew_point_2m;
      pressure = c.pressure_msl;
      windSpeed = c.wind_speed_10m;
      windDir = c.wind_direction_10m;
      precipNow = c.precipitation;
      weatherCode = c.weather_code;
      isDay = c.is_day === 1;

      const h = d.hourly;
      const i = Math.max(0, h.time.indexOf(c.time.slice(0, 13) + ":00"));

      visibility = h.visibility[i];
      uvIndex = h.uv_index[i];
      snowDepth = h.snow_depth[i];

      hourly = h.time.slice(i, i + 24).map((t, k) => ({
            time: t.slice(11, 16),
            temp: h.temperature_2m[i + k],
            code: h.weather_code[i + k],
            pop: h.precipitation_probability[i + k],
            wind: h.wind_speed_10m[i + k],
            day: h.is_day[i + k] === 1
          }));

      const dd = d.daily;

      daily = dd.time.map((t, k) => ({
            date: t,
            code: dd.weather_code[k],
            max: dd.temperature_2m_max[k],
            min: dd.temperature_2m_min[k],
            pop: dd.precipitation_probability_max[k],
            rain: dd.precipitation_sum[k],
            sunrise: dd.sunrise[k],
            sunset: dd.sunset[k]
          }));

      updated = Qt.formatDateTime(new Date(), "HH:mm");
      loaded = true;
      failed = false;
    } catch (e) {
      failed = true;
    }
  }

  function parseAir(text) {
    try {
      const c = JSON.parse(text).current;

      if (!c)
        return;
      aqi = c.us_aqi;
      pm25 = c.pm2_5;
      pm10 = c.pm10;
      no2 = c.nitrogen_dioxide;
      o3 = c.ozone;
      pollen = [
        {
          name: "Alder",
          value: c.alder_pollen
        },
        {
          name: "Birch",
          value: c.birch_pollen
        },
        {
          name: "Grass",
          value: c.grass_pollen
        }
      ];
      airLoaded = true;
    } catch (e) {
      airLoaded = false;
    }
  }

  // NotificationCard renders notification bodies as RichText.
  // Escape API text before placing it in that body.
  function escapeNotificationText(value) {
    return String(value === null || value === undefined ? "" : value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  function notifyNwsAlert(alert, placeName) {
    const details = [];

    if (placeName)
      details.push(escapeNotificationText(placeName));

    if (alert.headline)
      details.push(escapeNotificationText(alert.headline));

    const status = [];

    if (alert.severity)
      status.push("Severity: " + escapeNotificationText(alert.severity));

    if (alert.urgency)
      status.push("Urgency: " + escapeNotificationText(alert.urgency));

    if (status.length > 0)
      details.push(status.join(" · "));

    // Pass arguments directly, without a shell.
    Quickshell.execDetached([Tools.notifySend, "--app-name=NWS Weather Alerts", "--icon=weather-severe-alert", "--urgency=critical", "--expire-time=0", "--", alert.event || "National Weather Service alert", details.join("\n")]);
  }

  function parseAlerts(text, requestLocationKey, requestLocationName) {
    // Ignore an old response if the selected location changed
    // while its request was in flight.
    if (requestLocationKey !== alertLocationKey)
      return;
    try {
      const data = JSON.parse(text);

      // An API error is not an empty list of active alerts.
      if (!Array.isArray(data.features))
        throw new Error("NWS response has no features array");

      const nextAlerts = data.features.map(f => {
        const p = f.properties || {};

        return {
          id: String(f.id || p.id || ""),
          event: p.event || "Weather alert",
          severity: p.severity || "",
          urgency: p.urgency || "",
          headline: p.headline || "",
          description: p.description || "",
          instruction: p.instruction || "",
          sent: p.sent || "",
          expires: p.expires || "",
          status: p.status || "",
          messageType: p.messageType || ""
        };
      });

      // Preserve the existing popup's alert list, with extra fields
      // available if you want to display them later.
      alerts = nextAlerts;

      const seen = Object.assign({}, announcedAlertIds);
      const pending = [];

      for (const alert of nextAlerts) {
        // Do not announce test/exercise messages or cancellations.
        // Allow missing metadata rather than silently losing an alert.
        if (alert.status && alert.status !== "Actual")
          continue;
        if (alert.messageType === "Cancel")
          continue;

        // NWS alert IDs identify messages. A newly issued update
        // with a different ID will therefore also be announced.
        if (!alert.id || seen[alert.id])
          continue;
        seen[alert.id] = true;
        pending.push(alert);
      }

      // Record the IDs before dispatching the notifications.
      announcedAlertIds = seen;

      for (const alert of pending)
        notifyNwsAlert(alert, requestLocationName);
    } catch (e) {
      // Keep the last successful alert list and deduplication state
      // if the network fails or the API returns invalid data.
      console.warn("NWS alert fetch failed: " + String(e));
    }
  }

  // refresh every 15 minutes
  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // retries, and groups several changes (place, units) into one refresh
  Timer {
    id: retryTimer
    interval: 400
    repeat: false
    onTriggered: root.refresh()
  }

  onLatitudeChanged: retryTimer.restart()
  onLongitudeChanged: retryTimer.restart()
  onImperialChanged: retryTimer.restart()

  // ================= place search =================
  property var results: []           // [{ name, detail, latitude, longitude }]
  property bool searching: false

  Process {
    id: geo

    stdout: StdioCollector {
      onStreamFinished: {
        root.searching = false;

        try {
          root.results = (JSON.parse(text).results || []).map(r => ({
                name: r.name,
                detail: [r.admin1, r.country].filter(x => x).join(", "),
                latitude: r.latitude,
                longitude: r.longitude
              }));
        } catch (e) {
          root.results = [];
        }
      }
    }
  }

  function search(query) {
    const q = query.trim();

    if (q === "") {
      results = [];
      return;
    }

    if (geo.running)
      return;
    searching = true;
    geo.command = [Tools.curl, "-sS", "-m", "10", "-G", "--data-urlencode", "name=" + q, "-d", "count=8", "-d", "language=en", "-d", "format=json", "https://geocoding-api.open-meteo.com/v1/search"];
    geo.running = true;
  }

  // ================= weather code -> Weather Icons glyph =================
  function iconFor(code, day) {
    switch (code) {
    case 0:
      return day ? "\uf00d" : "\uf02e";
    case 1:
      return day ? "\uf00c" : "\uf083";
    case 2:
      return day ? "\uf002" : "\uf086";
    case 3:
      return "\uf013";
    case 45:
    case 48:
      return day ? "\uf003" : "\uf04a";
    case 51:
    case 53:
    case 55:
      return day ? "\uf00b" : "\uf02b";
    case 56:
    case 57:
      return day ? "\uf0b2" : "\uf0b4";
    case 61:
      return day ? "\uf008" : "\uf028";
    case 63:
    case 65:
      return "\uf019";
    case 66:
    case 67:
      return "\uf017";
    case 71:
      return day ? "\uf00a" : "\uf02a";
    case 73:
    case 75:
    case 77:
      return "\uf01b";
    case 80:
      return day ? "\uf009" : "\uf029";
    case 81:
    case 82:
      return "\uf01a";
    case 85:
    case 86:
      return "\uf01b";
    case 95:
      return day ? "\uf010" : "\uf02d";
    case 96:
    case 99:
      return "\uf01e";
    default:
      return "\uf07b";
    }
  }

  function describe(code) {
    switch (code) {
    case 0:
      return "Clear";
    case 1:
      return "Mainly clear";
    case 2:
      return "Partly cloudy";
    case 3:
      return "Overcast";
    case 45:
    case 48:
      return "Fog";
    case 51:
    case 53:
    case 55:
      return "Drizzle";
    case 56:
    case 57:
      return "Freezing drizzle";
    case 61:
      return "Light rain";
    case 63:
      return "Rain";
    case 65:
      return "Heavy rain";
    case 66:
    case 67:
      return "Freezing rain";
    case 71:
      return "Light snow";
    case 73:
      return "Snow";
    case 75:
    case 77:
      return "Heavy snow";
    case 80:
      return "Light showers";
    case 81:
      return "Showers";
    case 82:
      return "Violent showers";
    case 85:
    case 86:
      return "Snow showers";
    case 95:
      return "Thunderstorm";
    case 96:
    case 99:
      return "Thunderstorm, hail";
    default:
      return "No report";
    }
  }
}
