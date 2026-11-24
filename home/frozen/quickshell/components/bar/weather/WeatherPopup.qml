import QtQuick
import qs
import qs.components.shared
import "../../../lib/nav.js" as Nav

// The weather window: header, three tabs (details, forecast, radar) and a place picker.
// The window, frame and focus rules live in FramedWindow; this file holds only the weather layout.
Item {
  id: root

  property bool open: false
  property bool pinned: false
  property bool held: false             // stays open when it loses focus to a window it may coexist with

  signal closeRequested
  signal pinToggled

  // The Hyprland rule "qs-weather" in hyprland.lua must be this size plus the shadow (frame + 4).
  readonly property real frameWidth: 560
  readonly property real frameHeight: 720

  property int tab: 0                 // 0 = details, 1 = forecast, 2 = radar
  property bool locationOpen: false   // the place picker replaces the tab content

  onOpenChanged: {
    if (!open)
      locationOpen = false;
  }

  // small raised button for the header
  component HeaderButton: Item {
    id: hb

    property string glyph: ""
    signal clicked

    width: 30
    height: 24

    Rectangle {
      x: 2
      y: 2
      width: parent.width
      height: parent.height
      radius: Retro.corner
      color: Retro.shadowColor
      visible: !hbMouse.pressed
    }

    Rectangle {
      x: hbMouse.pressed ? 2 : 0
      y: hbMouse.pressed ? 2 : 0
      width: parent.width
      height: parent.height
      radius: Retro.corner
      color: Theme.bgAlt

      Text {
        anchors.centerIn: parent
        text: hb.glyph
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }

    MouseArea {
      id: hbMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: hb.clicked()
    }
  }

  // tab button: raised when idle, pressed in (with an orange label) when selected
  component TabButton: Item {
    id: tb

    property string label: ""
    property bool selected: false
    signal clicked

    height: 30

    Rectangle {
      x: 2
      y: 2
      width: parent.width
      height: parent.height
      radius: Retro.corner
      color: Retro.shadowColor
      visible: !tb.selected
    }

    Rectangle {
      anchors.fill: parent
      radius: Retro.corner
      color: tb.selected ? Theme.bgSel : Theme.bgAlt

      Text {
        anchors.centerIn: parent
        text: tb.label
        color: tb.selected ? Theme.orange : Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: tb.clicked()
    }
  }

  // Keyboard: Tab / arrows move between the controls (see nav.js), Enter or Space presses one,
  // Ctrl+1/2/3 or PageUp/PageDown change the tab, Esc closes the place picker and then the window.
  function handleKey(event) {
    if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
      tab = event.key - Qt.Key_1;
      locationOpen = false;
      event.accepted = true;
    } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
      tab = Math.max(0, Math.min(2, tab + (event.key === Qt.Key_PageDown ? 1 : -1)));
      locationOpen = false;
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape) {
      if (locationOpen)
        locationOpen = false;
      else if (!pinned)
        closeRequested();
      event.accepted = true;
    } else if (Nav.move(win.panel, event)) {
      event.accepted = true;
    }
  }

  FramedWindow {
    id: win
    windowTitle: "qs-weather"
    title: "Weather"
    open: root.open
    pinned: root.pinned
    held: root.held
    frameWidth: root.frameWidth
    frameHeight: root.frameHeight
    onCloseRequested: root.closeRequested()
    onPinToggled: root.pinToggled()
    onKeyPressed: event => root.handleKey(event)

    // ================= header =================
    Item {
      id: header
      x: 14
      y: 34
      width: parent.width - 28
      height: 140

      // location: click it to open the place picker
      Row {
        id: locRow
        spacing: 8

        Text {
          text: "\uf041"
          color: Theme.red
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize + 1
        }

        Text {
          width: 230
          elide: Text.ElideRight
          text: Weather.locationName
          color: Theme.fg
          font.family: Theme.fontSans
          font.bold: true
          font.pointSize: Theme.fontSize + 1
        }
      }

      MouseArea {
        anchors.fill: locRow
        cursorShape: Qt.PointingHandCursor
        onClicked: root.locationOpen = !root.locationOpen
      }

      // units, place search, refresh
      Row {
        id: headerButtons
        anchors.right: parent.right
        spacing: 6

        HeaderButton {
          glyph: Weather.tempUnit
          onClicked: Weather.toggleUnits()
        }
        HeaderButton {
          glyph: "\uf002"
          onClicked: root.locationOpen = !root.locationOpen
        }
        HeaderButton {
          glyph: "\uf021"
          onClicked: Weather.refresh()
        }
      }

      // the location's own date and time
      Text {
        anchors {
          right: headerButtons.left
          rightMargin: 14
          top: parent.top
          topMargin: 4
        }
        text: Weather.localTimeText
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      // the big temperature and conditions
      Text {
        x: 0
        y: 38
        text: Weather.tempText
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 22
      }

      Column {
        x: 0
        y: 104
        spacing: 2

        Text {
          text: Weather.loaded ? Weather.description.toUpperCase() : (Weather.failed ? "OFFLINE" : "LOADING")
          color: Weather.failed && !Weather.loaded ? Theme.red : Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize
        }

        Text {
          text: "FEELS LIKE " + Weather.fmt(Weather.feelsLike) + "°"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 1
        }
      }

      // the big icon
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36
        text: Weather.glyph
        color: Theme.fg
        font.family: "Weather Icons"
        font.pointSize: 44
      }

      // high and low
      Column {
        anchors.right: parent.right
        y: 44
        width: 80
        spacing: 2

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignRight
          text: "HIGH"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignRight
          text: Weather.fmt(Weather.high) + "°"
          color: Theme.orange
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 3
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignRight
          text: "LOW"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignRight
          text: Weather.fmt(Weather.low) + "°"
          color: Theme.blue
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize + 3
        }
      }
    }

    // ================= tabs =================
    Row {
      id: tabs
      x: 14
      y: 182
      width: parent.width - 28
      spacing: 8

      TabButton {
        width: (tabs.width - 16) / 3
        label: "DETAILS"
        selected: root.tab === 0 && !root.locationOpen
        onClicked: {
          root.tab = 0;
          root.locationOpen = false;
        }
      }

      TabButton {
        width: (tabs.width - 16) / 3
        label: "FORECAST"
        selected: root.tab === 1 && !root.locationOpen
        onClicked: {
          root.tab = 1;
          root.locationOpen = false;
        }
      }

      TabButton {
        width: (tabs.width - 16) / 3
        label: "RADAR"
        selected: root.tab === 2 && !root.locationOpen
        onClicked: {
          root.tab = 2;
          root.locationOpen = false;
        }
      }
    }

    // ================= tab content =================
    Item {
      id: pages
      x: 14
      y: 222
      width: parent.width - 28
      height: parent.height - 222 - 34

      WeatherDetails {
        anchors.fill: parent
        visible: root.tab === 0 && !root.locationOpen
      }

      WeatherForecast {
        anchors.fill: parent
        visible: root.tab === 1 && !root.locationOpen
      }

      // the radar only loads while its tab is showing, so it doesn't use the network otherwise
      Loader {
        anchors.fill: parent
        active: root.open && root.tab === 2 && !root.locationOpen
        visible: active
        sourceComponent: Component {
          WeatherRadar {}
        }
      }

      WeatherLocation {
        anchors.fill: parent
        visible: root.locationOpen
        onDone: root.locationOpen = false
      }
    }

    // footer
    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
        bottomMargin: 10
      }
      text: "UPDATED " + (Weather.updated !== "" ? Weather.updated : "--:--") + "  ·  WEATHER: OPEN-METEO"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 3
    }
  }
}
