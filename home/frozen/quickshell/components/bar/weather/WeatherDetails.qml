import QtQuick
import qs

// The "Details" tab: current conditions, sun and moon, air quality, pollen, alerts.
Flickable {
  id: flick

  clip: true
  contentWidth: width
  contentHeight: column.implicitHeight
  boundsBehavior: Flickable.StopAtBounds

  readonly property real gap: 8

  readonly property var stats: [
    {
      label: "HUMIDITY",
      value: Weather.fmt(Weather.humidity) + "%"
    },
    {
      label: "PRESSURE",
      value: Weather.pressureText
    },
    {
      label: "WIND",
      value: Weather.windText
    },
    {
      label: "DEW POINT",
      value: Weather.dewPoint === null ? "--" : Weather.fmt(Weather.dewPoint) + Weather.tempUnit
    },
    {
      label: "VISIBILITY",
      value: Weather.visibilityText
    },
    {
      label: "PRECIP TODAY",
      value: Weather.fmt(Weather.precipToday, 1) + " " + Weather.precipUnit
    },
    {
      label: "PRECIP NOW",
      value: Weather.fmt(Weather.precipNow, 1) + " " + Weather.precipUnit
    },
    {
      label: "UV INDEX",
      value: Weather.uvText
    },
    {
      label: "SNOW COVER",
      value: Weather.snowText
    },
    {
      label: "CLOUD COVER",
      value: Weather.fmt(Weather.cloudCover) + "%"
    }
  ]

  Column {
    id: column
    width: flick.width
    spacing: flick.gap

    // ---- stat boxes ----
    Grid {
      width: parent.width
      columns: 2
      spacing: flick.gap

      Repeater {
        model: flick.stats

        Rectangle {
          required property var modelData

          width: (column.width - flick.gap) / 2
          height: 30
          radius: 3
          color: Qt.rgba(0, 0, 0, 0.35)
          border.color: Theme.fgDim
          border.width: Retro.borderWidth

          Text {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
              leftMargin: 10
            }
            text: parent.modelData.label
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 2
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
              rightMargin: 10
            }
            text: parent.modelData.value
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }
        }
      }
    }

    // ---- sun and moon ----
    Row {
      spacing: flick.gap

      WeatherCard {
        id: sunCard
        width: (column.width - flick.gap) / 2
        height: Math.max(sunCard.implicitHeight, moonCard.implicitHeight)
        title: "SUN"

        Canvas {
          id: arc
          width: parent.width
          height: 70

          property real p: Weather.sunProgress

          onPChanged: requestPaint()
          onWidthChanged: requestPaint()

          onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height - 4;
            const r = Math.min(width / 2 - 8, height - 10);

            // the whole path of the sun, faint
            ctx.lineWidth = 2;
            ctx.strokeStyle = Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25);
            ctx.beginPath();
            ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI);
            ctx.stroke();

            if (p < 0 || p > 1)
              return;

            // the part already travelled, and the sun itself
            ctx.strokeStyle = Theme.yellow;
            ctx.beginPath();
            ctx.arc(cx, cy, r, Math.PI, Math.PI + p * Math.PI);
            ctx.stroke();

            const a = Math.PI + p * Math.PI;
            ctx.fillStyle = Theme.yellow;
            ctx.beginPath();
            ctx.arc(cx + r * Math.cos(a), cy + r * Math.sin(a), 5, 0, 2 * Math.PI);
            ctx.fill();
          }
        }

        Item {
          width: parent.width
          height: 16

          Text {
            anchors.left: parent.left
            text: Weather.sunriseText
            color: Theme.orange
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }

          Text {
            anchors.right: parent.right
            text: Weather.sunsetText
            color: Theme.orange
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "DAY " + Weather.dayLengthText
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Weather.sunUp ? Weather.sunLeftText + " LEFT" : "SUN IS DOWN"
          color: Theme.orange
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }
      }

      WeatherCard {
        id: moonCard
        width: (column.width - flick.gap) / 2
        height: Math.max(sunCard.implicitHeight, moonCard.implicitHeight)
        title: "MOON"

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Weather.moonGlyph
          color: Theme.fg
          font.family: "Weather Icons"
          font.pointSize: 34
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Weather.moonName.toUpperCase()
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Math.round(Weather.moonIllumination * 100) + "% LIT"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }
      }
    }

    // ---- air quality ----
    WeatherCard {
      width: column.width
      title: "AIR QUALITY"

      Item {
        width: parent.width
        height: 20

        Text {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
          }
          text: "US AQI"
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Text {
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          text: Weather.airLoaded ? Weather.fmt(Weather.aqi) + "  " + Weather.aqiLabel : "NO DATA"
          color: Weather.airLoaded ? Weather.aqiColor : Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      Repeater {
        model: [
          {
            label: "PM2.5",
            value: Weather.pm25,
            max: 75
          },
          {
            label: "PM10",
            value: Weather.pm10,
            max: 150
          },
          {
            label: "NO2",
            value: Weather.no2,
            max: 200
          },
          {
            label: "OZONE",
            value: Weather.o3,
            max: 200
          }
        ]

        Column {
          id: pollutant
          required property var modelData

          width: parent.width
          spacing: 3

          Item {
            width: parent.width
            height: 16

            Text {
              anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
              }
              text: pollutant.modelData.label
              color: Theme.fgDim
              font.family: Theme.fontMono
              font.pointSize: Theme.fontSize - 2
            }

            Text {
              anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
              }
              text: Weather.fmt(pollutant.modelData.value, 1) + " µg/m³"
              color: Theme.fg
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize - 2
            }
          }

          Rectangle {
            width: parent.width
            height: 6
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)

            Rectangle {
              width: pollutant.modelData.value === null ? 0 : parent.width * Math.min(1, pollutant.modelData.value / pollutant.modelData.max)
              height: parent.height
              color: Weather.aqiColor
            }
          }
        }
      }
    }

    // ---- pollen ----
    WeatherCard {
      width: column.width
      title: "POLLEN"

      Text {
        width: parent.width
        visible: !Weather.hasPollen
        wrapMode: Text.Wrap
        text: "NO POLLEN DATA FOR THIS LOCATION (EUROPE ONLY)"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }

      Repeater {
        model: Weather.hasPollen ? Weather.pollen : []

        Item {
          required property var modelData

          width: parent.width
          height: 18

          Text {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            text: parent.modelData.name.toUpperCase()
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 2
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: parent.modelData.value === null || parent.modelData.value === undefined ? "--" : Weather.fmt(parent.modelData.value, 1) + " grains/m³  " + Weather.pollenLevel(parent.modelData.value)
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 2
          }
        }
      }
    }

    // ---- alerts ----
    WeatherCard {
      width: column.width
      title: "ALERTS (US NWS)"

      Text {
        width: parent.width
        visible: Weather.alerts.length === 0
        text: "NO ACTIVE ALERTS"
        color: Theme.green
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Repeater {
        model: Weather.alerts

        Text {
          required property var modelData

          width: parent.width
          wrapMode: Text.Wrap
          text: modelData.event.toUpperCase()
          color: modelData.severity === "Extreme" || modelData.severity === "Severe" ? Theme.red : Theme.orange
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }
    }
  }
}
