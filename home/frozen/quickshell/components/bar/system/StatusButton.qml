import Quickshell
import QtQuick
import qs
import qs.components.shared

// The system button in the top bar: temperature | cpu | memory | battery.
//   click          opens the system popup (the bar reacts to `clicked`)
//   middle click   a terminal with htop
//   scroll         the power profile: up = toward performance, down = toward energy saving
Item {
  id: button

  property bool open: false

  signal clicked

  readonly property real padX: 9
  readonly property string batteryPath: SystemStats.batteryIconName !== "" ? (Quickshell.iconPath(SystemStats.batteryIconName, true) || "") : ""

  // one "glyph value" pair
  component Stat: Row {
    property string glyph: ""
    property string value: ""
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: parent.glyph
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }

  component Sep: Rectangle {
    width: 2
    height: 14
    color: Theme.fgDim
  }

  width: statusRow.implicitWidth + padX * 2
  height: 22

  KeyFace {
    anchors.fill: parent
    down: button.open
  }

  Row {
    id: statusRow
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: mouse.pressed ? 1 : 0
    anchors.verticalCenterOffset: mouse.pressed ? 1 : 0
    spacing: 7

    Stat {
      glyph: "\uf2c9"                 // thermometer
      value: SystemStats.tempText
    }
    Sep {
      anchors.verticalCenter: parent.verticalCenter
    }
    Stat {
      glyph: "\uf2db"                 // microchip
      value: SystemStats.cpuText
    }
    Sep {
      anchors.verticalCenter: parent.verticalCenter
    }
    Stat {
      glyph: SystemStats.memGlyph
      value: SystemStats.memText
    }

    Sep {
      anchors.verticalCenter: parent.verticalCenter
      visible: SystemStats.hasBattery
    }

    // battery icon from the icon pack (a Nerd Font glyph if it can't be found)
    Item {
      anchors.verticalCenter: parent.verticalCenter
      visible: SystemStats.hasBattery
      width: 16
      height: 16

      Image {
        id: batteryImage
        anchors.fill: parent
        sourceSize.width: 32
        sourceSize.height: 32
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        source: button.batteryPath
        visible: source !== ""
      }

      Text {
        anchors.centerIn: parent
        visible: !batteryImage.visible
        text: "\uf240"
        color: Theme.fg
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    property real wheelAccum: 0

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton)
        Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", "htop", Tools.htop]);
      else
        button.clicked();
    }

    // waits for a full notch (touchpads send many small steps)
    onWheel: wheel => {
      wheel.accepted = true;
      wheelAccum += wheel.angleDelta.y;
      if (Math.abs(wheelAccum) < 120)
        return;
      const delta = wheelAccum > 0 ? 1 : -1;
      wheelAccum = 0;
      SystemStats.stepProfile(delta);
    }
  }
}
