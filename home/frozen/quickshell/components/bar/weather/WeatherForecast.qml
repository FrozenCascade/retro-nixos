import QtQuick
import qs

// The "Forecast" tab: the next 24 hours as a smooth scrolling strip, then the next 7 days.
Flickable {
  id: flick

  clip: true
  contentWidth: width
  contentHeight: column.implicitHeight
  boundsBehavior: Flickable.StopAtBounds

  Column {
    id: column
    width: flick.width
    spacing: 8

    Text {
      text: "NEXT 24 HOURS"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Rectangle {
      width: parent.width
      height: 178
      radius: 3
      color: Qt.rgba(0, 0, 0, 0.35)
      border.color: Theme.fgDim
      border.width: Retro.borderWidth

      ListView {
        id: hours
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
          bottom: scrollBar.top
          margins: 4
        }
        orientation: ListView.Horizontal
        clip: true
        model: Weather.hourly
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2500
        maximumFlickVelocity: 3000

        // where the smooth scroll is heading
        property real goal: 0

        function clampX(x) {
          return Math.max(0, Math.min(Math.max(0, contentWidth - width), x));
        }

        // scroll by dx pixels with a short glide; repeated calls add up
        function glideBy(dx) {
          goal = clampX((glide.running ? goal : contentX) + dx);
          glide.stop();
          glide.from = contentX;
          glide.to = goal;
          glide.start();
        }

        NumberAnimation {
          id: glide
          target: hours
          property: "contentX"
          duration: 240
          easing.type: Easing.OutCubic
        }

        // grabbing the strip with the mouse cancels any glide in progress
        onMovementStarted: glide.stop()

        delegate: Item {
          id: cell
          required property var modelData
          required property int index

          width: 64
          height: hours.height

          Rectangle {
            visible: cell.index > 0
            x: 0
            y: 8
            width: 1
            height: parent.height - 16
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
          }

          Column {
            anchors.centerIn: parent
            spacing: 9

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: cell.index === 0 ? "NOW" : cell.modelData.time
              color: cell.index === 0 ? Theme.orange : Theme.fgDim
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize - 2
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.iconFor(cell.modelData.code, cell.modelData.day)
              color: Theme.fg
              font.family: "Weather Icons"
              font.pointSize: Theme.fontSize + 6
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.fmt(cell.modelData.temp) + "°"
              color: Theme.fg
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize + 1
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\uf0e9 " + Weather.fmt(cell.modelData.pop) + "%"
              color: Theme.blue
              font.family: Theme.fontMono
              font.pointSize: Theme.fontSize - 2
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.fmt(cell.modelData.wind) + " " + Weather.speedUnit
              color: Theme.fgDim
              font.family: Theme.fontMono
              font.pointSize: Theme.fontSize - 3
            }
          }
        }

        // the mouse wheel and touchpad scroll the strip sideways, smoothly
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton

          onWheel: wheel => {
            const px = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : (wheel.angleDelta.y + wheel.angleDelta.x) * 1.4;

            hours.glideBy(-px);
          }
        }
      }

      // ---- scroll bar: drag the handle, or click the track to jump ----
      Rectangle {
        id: scrollBar
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          margins: 6
        }
        height: 10
        radius: 2
        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)

        Rectangle {
          id: handle
          height: parent.height
          radius: 2
          width: Math.max(28, parent.width * hours.width / Math.max(hours.contentWidth, 1))
          x: hours.contentWidth > hours.width ? hours.contentX / (hours.contentWidth - hours.width) * (parent.width - width) : 0
          color: barMouse.pressed ? Theme.orange : Theme.fgDim
        }

        MouseArea {
          id: barMouse
          anchors {
            fill: parent
            topMargin: -6
            bottomMargin: -6
          }
          preventStealing: true
          cursorShape: Qt.PointingHandCursor

          function seek(mx) {
            const room = Math.max(1, scrollBar.width - handle.width);
            const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / room));

            glide.stop();
            hours.contentX = f * Math.max(0, hours.contentWidth - hours.width);
            hours.goal = hours.contentX;
          }

          onPressed: mouse => seek(mouse.x)
          onPositionChanged: mouse => {
            if (pressed)
              seek(mouse.x);
          }
        }
      }
    }

    Text {
      text: "NEXT 7 DAYS"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Repeater {
      model: Weather.daily.slice(0, 8)

      Rectangle {
        id: dayRow
        required property var modelData
        required property int index

        width: column.width
        height: 38
        radius: 3
        color: Qt.rgba(0, 0, 0, 0.35)
        border.color: Theme.fgDim
        border.width: Retro.borderWidth

        Text {
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 92
          text: Weather.dayName(dayRow.index, dayRow.modelData.date)
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Text {
          x: 108
          anchors.verticalCenter: parent.verticalCenter
          width: 26
          horizontalAlignment: Text.AlignHCenter
          text: Weather.iconFor(dayRow.modelData.code, true)
          color: Theme.fg
          font.family: "Weather Icons"
          font.pointSize: Theme.fontSize + 3
        }

        Text {
          x: 142
          anchors.verticalCenter: parent.verticalCenter
          width: 170
          elide: Text.ElideRight
          text: Weather.describe(dayRow.modelData.code)
          color: Theme.fgDim
          font.family: Theme.fontSans
          font.pointSize: Theme.fontSize - 1
        }

        Text {
          anchors {
            right: temps.left
            verticalCenter: parent.verticalCenter
            rightMargin: 14
          }
          text: "\uf0e9 " + Weather.fmt(dayRow.modelData.pop) + "%"
          color: Theme.blue
          font.family: Theme.fontMono
          font.pointSize: Theme.fontSize - 2
        }

        Row {
          id: temps
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 10
          }
          spacing: 4

          Text {
            text: Weather.fmt(dayRow.modelData.min) + "°"
            color: Theme.blue
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }

          Text {
            text: "/"
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 1
          }

          Text {
            text: Weather.fmt(dayRow.modelData.max) + "°"
            color: Theme.orange
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }
        }
      }
    }
  }
}
