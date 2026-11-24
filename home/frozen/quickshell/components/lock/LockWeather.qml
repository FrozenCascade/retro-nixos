import QtQuick
import qs

// Left side of the lock window: the weather now, from the same data as the bar's weather button.
Rectangle {
  id: card

  radius: Retro.corner
  color: Retro.inset
  border.width: Retro.borderWidth
  border.color: Theme.fgDim

  // one label/value line each; adding a line is one entry here
  readonly property var rows: [
    { k: "FEELS", v: Weather.hidden ? "--" : Weather.loaded ? Weather.fmt(Weather.feelsLike) + "°" : "--" },
    { k: "HIGH / LOW", v: Weather.hidden ? "--" : Weather.loaded ? Weather.fmt(Weather.high) + "° / " + Weather.fmt(Weather.low) + "°" : "--" },
    { k: "WIND", v: Weather.hidden ? "--" : Weather.windText },
    { k: "HUMIDITY", v: Weather.hidden ? "--" : Weather.loaded ? Weather.humidity + "%" : "--" },
    { k: "PRESSURE", v: Weather.hidden ? "--" : Weather.loaded ? Weather.pressureText : "--" },
    { k: "VISIBILITY", v: Weather.hidden ? "--" : Weather.loaded ? Weather.visibilityText : "--" },
    { k: "UV INDEX", v: Weather.hidden ? "--" : Weather.loaded ? Weather.uvText : "--" },
    { k: "AIR QUALITY", v: Weather.hidden ? "--" : Weather.airLoaded ? Weather.aqi + " " + Weather.aqiLabel.split(" ")[0] : "--" }
  ]

  Column {
    x: 14
    y: 14
    width: parent.width - 28
    spacing: 8

    Text {
      text: Weather.hidden ? "WEATHER HIDDEN" : Weather.locationName.toUpperCase()
      width: parent.width
      elide: Text.ElideRight
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 2
    }

    Row {
      spacing: 14

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.glyph
        visible: !Weather.hidden
        color: Theme.orange
        font.family: "Weather Icons"
        font.pointSize: Theme.fontSize + 18
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.hidden ? "---" : Weather.tempText
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 10
      }
    }

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: Weather.hidden ? "NO WEATHER AVAILABLE" : Weather.loaded ? Weather.description.toUpperCase() : (Weather.failed ? "OFFLINE" : "LOADING")
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Rectangle {
      width: parent.width
      height: Retro.borderWidth
      color: Theme.fgDim
      opacity: 0.5
    }

    Column {
      width: parent.width
      spacing: 2

      Repeater {
        model: card.rows

        Item {
          required property var modelData

          width: parent.width
          height: 18

          Text {
            text: parent.modelData.k
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 2
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: parent.width - 96
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: parent.modelData.v
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 2
          }
        }
      }
    }
  }
}
