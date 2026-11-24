import QtQuick
import qs

// What each screen shows while locked: the picture, blurred and dimmed, and one retro window.
//   left    weather               (LockWeather)
//   middle  photo, time, password (LockAccount)
//   right   music                 (LockPlayer)
//   bottom  sleep / logout / restart / shutdown (LockPower)
Item {
  id: surface

  required property var controller

  // the monitor this surface covers, so its own wallpaper can be the backdrop
  property string screenName: Window.window && Window.window.screen ? Window.window.screen.name : ""

  // sizes of the window; the three columns share the width
  readonly property real pad: 16
  readonly property real sideWidth: 230
  readonly property real columnsHeight: 330

  LockBackdrop {
    anchors.fill: parent
    screenName: surface.screenName
  }

  Item {
    id: card
    width: 900
    height: 36 + surface.columnsHeight + 12 + 56 + surface.pad
    anchors.centerIn: parent

    Rectangle {
      x: Retro.shadowOffset
      y: Retro.shadowOffset
      width: frame.width
      height: frame.height
      radius: Retro.corner
      color: Retro.shadowColor
    }

    Rectangle {
      id: frame
      width: card.width
      height: card.height
      radius: Retro.corner
      color: Theme.bg
      border.color: Theme.fg
      border.width: Retro.borderWidth

      Rectangle {
        x: Retro.borderWidth
        y: Retro.borderWidth
        width: parent.width - Retro.borderWidth * 2
        height: 24
        color: Theme.fg

        LockBattery {
          anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        }

        Text {
          anchors.centerIn: parent
          text: "LOCKED"
          color: Theme.bg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      LockWeather {
        id: weather
        x: surface.pad
        y: 36
        width: surface.sideWidth
        height: surface.columnsHeight
      }

      LockAccount {
        id: account
        x: weather.x + weather.width + surface.pad
        y: 36
        width: parent.width - (surface.sideWidth + surface.pad) * 2 - surface.pad * 2
        height: surface.columnsHeight
        controller: surface.controller
      }

      LockPlayer {
        x: parent.width - surface.pad - surface.sideWidth
        y: 36
        width: surface.sideWidth
        height: surface.columnsHeight
      }

      LockPower {
        x: surface.pad
        y: 36 + surface.columnsHeight + 12
        width: parent.width - surface.pad * 2
      }
    }
  }

  Connections {
    target: surface.controller
    function onCleared() {
      account.refocus();
    }
  }
}
