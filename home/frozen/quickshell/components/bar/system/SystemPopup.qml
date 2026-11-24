import Quickshell
import QtQuick
import qs
import qs.components.shared

// The system popup. The bar tells it where to open, whether it is open, and whether it is pinned.
Item {
  id: root

  property bool open: false
  property bool pinned: false
  property real frameWidth: 340
  property var anchorWindow: null
  property real anchorX: 0
  property real anchorY: 0
  property real anchorWidth: 0

  // the popup window itself, so the bar's shared click-outside handler can include it
  readonly property var popupWindow: popup

  signal closeRequested
  signal pinToggled


  // power profile buttons, left to right (Nerd Font icons)
  readonly property var profiles: [
    {
      name: "performance",
      glyph: "\uf135"
    }     // rocket
    ,
    {
      name: "balanced",
      glyph: "\uf24e"
    }     // balance scale
    ,
    {
      name: "power-saver",
      glyph: "\uf06c"
    }      // leaf
  ]

  readonly property string batteryPath: SystemStats.batteryIconName !== "" ? (Quickshell.iconPath(SystemStats.batteryIconName, true) || "") : ""

  // small gray label
  component Dim: Text {
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 1
  }

  // small gray divider line
  component Rule: Rectangle {
    width: parent ? parent.width : 0
    height: 2
    color: Theme.fgDim
  }

  PopupWindow {
    id: popup
    visible: root.open
    color: "transparent"

    anchor.window: root.anchorWindow
    anchor.rect.x: root.anchorX
    anchor.rect.y: root.anchorY
    anchor.rect.width: root.anchorWidth
    anchor.rect.height: 1
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: frame.width + Retro.shadowOffset
    implicitHeight: frame.height + Retro.shadowOffset

    // hard drop shadow
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
      width: root.frameWidth
      height: body.y + body.implicitHeight + 14

      radius: Retro.corner
      color: Theme.bg
      border.color: Theme.fg
      border.width: Retro.borderWidth

      // swallow clicks on empty areas
      MouseArea {
        anchors.fill: parent
      }

      // title bar: \\\ SYSTEM   [+] [x]
      TitleBar {
        title: "System"
        showPin: true
        pinned: root.pinned
        onPinClicked: root.pinToggled()
        onCloseClicked: root.closeRequested()
      }

      Column {
        id: body
        x: 14
        y: 38
        width: parent.width - 28
        spacing: 10

        // ---- power profile: three indented buttons ----
        Row {
          width: parent.width
          spacing: 8

          Repeater {
            model: root.profiles

            Item {
              id: profileButton
              required property var modelData

              readonly property bool active: SystemStats.profileName === modelData.name
              readonly property bool available: modelData.name !== "performance" || SystemStats.hasPerformance

              width: (parent.width - 16) / 3
              height: 36
              opacity: available ? 1.0 : 0.35

              // the well
              Rectangle {
                anchors.fill: parent
                radius: Retro.corner
                color: profileButton.active ? Theme.bgSel : Retro.inset
                border.width: Retro.borderWidth
                border.color: profileButton.active ? Theme.orange : Theme.fgDim

                // inner shadow on the top and left edges: this is what makes it look indented
                Rectangle {
                  x: 2
                  y: 2
                  width: parent.width - 4
                  height: 2
                  color: Qt.rgba(0, 0, 0, 0.5)
                }

                Rectangle {
                  x: 2
                  y: 2
                  width: 2
                  height: parent.height - 4
                  color: Qt.rgba(0, 0, 0, 0.5)
                }
              }

              Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: profileMouse.pressed ? 1 : 0
                anchors.verticalCenterOffset: profileMouse.pressed ? 1 : 0
                text: profileButton.modelData.glyph
                color: profileButton.active ? Theme.orange : Theme.fgDim
                font.family: Theme.fontMono
                font.pointSize: Theme.fontSize + 3
              }

              MouseArea {
                id: profileMouse
                anchors.fill: parent
                enabled: profileButton.available
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemStats.setProfileByName(profileButton.modelData.name)
              }
            }
          }
        }

        // ---- battery: icon and percentage, time left on the right ----
        Item {
          width: parent.width
          height: 28

          Row {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: 22
              height: 22

              Image {
                id: batteryImage
                anchors.fill: parent
                sourceSize.width: 44
                sourceSize.height: 44
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                source: root.batteryPath
                visible: source !== ""
              }

              Text {
                anchors.centerIn: parent
                visible: !batteryImage.visible
                text: "\uf240"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pointSize: Theme.fontSize + 2
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: SystemStats.hasBattery ? SystemStats.battery + "%" : "N/A"
              color: Theme.fg
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize + 2
            }
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: SystemStats.batteryTimeText
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }
        }

        Rule {}

        // ---- section 1: CPU temperature, with the per-core bar graph ----
        Item {
          width: parent.width
          height: 20

          Dim {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            text: "CPU TEMP"
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: SystemStats.temp + "°C"
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize + 1
          }
        }

        CoreBars {
          width: parent.width
          values: SystemStats.cores
        }

        Rule {}

        // ---- section 2: CPU usage over time ----
        Item {
          width: parent.width
          height: 20

          Dim {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            text: "CPU USAGE"
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: SystemStats.cpu + "%"
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize + 1
          }
        }

        LineGraph {
          width: parent.width
          values: SystemStats.cpuHistory
          historyLength: SystemStats.historyLength
          maxValue: 100
          lineColor: Theme.orange
          topLabel: "100%"
          bottomLabel: "0%"
        }

        Rule {}

        // ---- section 3: memory usage over time ----
        Item {
          width: parent.width
          height: 38

          Dim {
            anchors {
              left: parent.left
              top: parent.top
              topMargin: 2
            }
            text: "MEMORY USAGE"
          }

          Text {
            anchors {
              right: parent.right
              top: parent.top
            }
            text: SystemStats.mem + "%"
            color: Theme.fg
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize + 1
          }

          Text {
            anchors {
              right: parent.right
              bottom: parent.bottom
            }
            text: SystemStats.memUsedGb.toFixed(1) + " / " + SystemStats.memTotalGb.toFixed(1) + " GB"
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
          }
        }

        LineGraph {
          width: parent.width
          values: SystemStats.memHistory
          historyLength: SystemStats.historyLength
          maxValue: Math.max(1, Math.ceil(SystemStats.memTotalGb))
          lineColor: Theme.aqua
          topLabel: Math.ceil(SystemStats.memTotalGb) + " GB"
          bottomLabel: "0 GB"
        }

        Rule {}

        // ---- small section: swap (no graph) ----
        Item {
          width: parent.width
          height: 22

          Dim {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            text: "SWAP USAGE"
          }

          Row {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            spacing: 10

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: SystemStats.swapTotalGb > 0
              text: SystemStats.swapPercent + "%"
              color: Theme.fg
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize + 1
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: SystemStats.swapTotalGb > 0 ? SystemStats.swapUsedGb.toFixed(1) + " / " + SystemStats.swapTotalGb.toFixed(1) + " GB" : "NO SWAP"
              color: Theme.fgDim
              font.family: Theme.fontMono
              font.bold: true
              font.pointSize: Theme.fontSize - 1
            }
          }
        }
      }
    }
  }
}
