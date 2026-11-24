import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// The WI-FI tab: networks in range, the connected one first. A new secured network asks for its password
// in a box under its row. Saved networks reconnect without one.
Flickable {
  id: flick

  property string asking: ""            // the network waiting for a password
  property bool hideNames: false        // HIDE NAMES: the networks show as stars (remembered between runs)

  readonly property string mask: "********"

  function shown(ssid) {
    return hideNames ? mask : ssid;
  }

  StatePrefs {
    id: prefs
    file: "wifi-tab.json"
    data: ({ hideNames: flick.hideNames })
    onLoaded: saved => flick.hideNames = saved.hideNames === true
  }

  readonly property var sorted: NetState.wifiNetworks.slice().sort((a, b) => (Number(b.active) - Number(a.active)) || (b.signal - a.signal))

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
        width: parent.width - buttons.width - 10
        text: "NETWORKS"
      }

      Row {
        id: buttons
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 6

        MiniButton {
          text: "HIDE NAMES"
          active: flick.hideNames
          onClicked: {
            flick.hideNames = !flick.hideNames;
            prefs.save();
          }
        }

        MiniButton {
          enabled: NetState.wifiEnabled
          text: "RESCAN"
          onClicked: NetState.rescan()
        }
      }
    }

    Text {
      visible: !NetState.wifiEnabled
      text: "WI-FI IS OFF"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Text {
      visible: NetState.wifiEnabled && flick.sorted.length === 0
      text: "NO NETWORKS FOUND"
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    Text {
      visible: NetState.wifiError !== ""
      width: parent.width
      wrapMode: Text.WordWrap
      text: NetState.wifiError
      color: Theme.red
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 2
    }

    Repeater {
      model: NetState.wifiEnabled ? flick.sorted : []

      delegate: Column {
        id: item

        required property var modelData
        readonly property bool saved: NetState.savedWifi.indexOf(modelData.ssid) !== -1

        width: col.width
        spacing: 6

        ConnectionRow {
          width: parent.width
          glyph: NetState.wifiGlyph(item.modelData.signal)
          glyphTint: item.modelData.active ? Theme.green : Theme.fg
          title: flick.shown(item.modelData.ssid)
          sub: (item.modelData.active ? "CONNECTED   " : (NetState.wifiBusy === item.modelData.ssid ? "CONNECTING   " : "")) + item.modelData.signal + "%   " + (item.modelData.secure ? "SECURED" : "OPEN")
          highlight: item.modelData.active

          MiniButton {
            visible: item.modelData.active
            text: "DISCONNECT"
            onClicked: NetState.wifiDisconnect()
          }

          MiniButton {
            visible: !item.modelData.active
            text: "CONNECT"
            onClicked: {
              if (item.saved || !item.modelData.secure) {
                NetState.wifiConnect(item.modelData.ssid, "");
              } else {
                flick.asking = item.modelData.ssid;
                Qt.callLater(password.focusIt);
              }
            }
          }

          MiniButton {
            visible: item.saved
            text: "FORGET"
            danger: true
            onClicked: NetState.wifiForget(item.modelData.ssid)
          }
        }

        FieldBox {
          id: password
          visible: flick.asking === item.modelData.ssid
          width: parent.width
          echoMode: TextInput.Password
          placeholder: "PASSWORD FOR " + (flick.hideNames ? "THIS NETWORK" : item.modelData.ssid.toUpperCase())
          onAccepted: {
            NetState.wifiConnect(item.modelData.ssid, text);
            text = "";
            flick.asking = "";
          }
          onEscaped: {
            text = "";
            flick.asking = "";
          }
        }
      }
    }
  }
}
