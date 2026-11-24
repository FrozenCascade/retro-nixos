import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// The BLUETOOTH tab: connected devices first, then paired ones, then whatever a scan found.
// Pairing needs a Bluetooth agent in the session (Blueman's applet provides one).
Flickable {
  id: flick

  readonly property var sorted: NetState.btDevices.slice().sort((a, b) => (Number(b.connected) - Number(a.connected)) || (Number(b.paired) - Number(a.paired)) || String(a.name).localeCompare(String(b.name)))

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 8

    Item {
      width: parent.width
      height: 26

      SectionHead {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 90
        text: "DEVICES"
      }

      MiniButton {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        enabled: NetState.btEnabled
        active: NetState.btScanning
        text: NetState.btScanning ? "SCANNING" : "SCAN"
        onClicked: NetState.btScan(!NetState.btScanning)
      }
    }

    Text {
      visible: !NetState.btPresent || !NetState.btEnabled || flick.sorted.length === 0
      text: !NetState.btPresent ? "NO BLUETOOTH ADAPTER" : (!NetState.btEnabled ? "BLUETOOTH IS OFF" : "NO DEVICES, TRY SCAN")
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Repeater {
      model: NetState.btEnabled ? flick.sorted : []

      delegate: ConnectionRow {
        id: item

        required property var modelData
        readonly property int battery: NetState.btBattery(modelData)

        width: col.width
        glyph: NetState.btGlyph(modelData)
        glyphTint: modelData.connected ? Theme.blue : Theme.fg
        title: modelData.name || modelData.address
        sub: (modelData.connected ? "CONNECTED" : (modelData.pairing ? "PAIRING" : (modelData.paired ? "PAIRED" : "NEW"))) + (battery >= 0 ? "   BATTERY " + battery + "%" : "")
        highlight: modelData.connected

        MiniButton {
          visible: item.modelData.connected
          text: "DISCONNECT"
          onClicked: item.modelData.disconnect()
        }

        MiniButton {
          visible: !item.modelData.connected && item.modelData.paired
          text: "CONNECT"
          onClicked: item.modelData.connect()
        }

        MiniButton {
          visible: !item.modelData.paired
          text: "PAIR"
          onClicked: item.modelData.pair()
        }

        MiniButton {
          visible: item.modelData.paired
          text: "FORGET"
          danger: true
          onClicked: item.modelData.forget()
        }
      }
    }
  }
}
