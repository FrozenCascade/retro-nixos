import Quickshell
import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// The VPN tab: the active connection and the saved VPN connections of NetworkManager.
//
// To add a server: download a WireGuard file for it (Proton: account.protonvpn.com > Downloads > WireGuard
// configuration, pick the country and server, create, download) and drop the .conf on the box at the bottom.
// Mark one saved connection as DEFAULT and the bar button's middle click connects to it.
// The Proton app keeps its own server list; OPEN PROTON VPN starts it for that.
Flickable {
  id: flick

  // ---- edit here ----
  // the command that starts the Proton VPN app (nixpkgs: protonvpn-gui installs "protonvpn-app")
  readonly property var protonCommand: ["protonvpn-app"]

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  Column {
    id: col
    width: flick.width
    spacing: 8

    SectionHead { width: parent.width; text: "STATUS" }

    ConnectionRow {
      width: parent.width
      glyph: Glyphs.vpn
      glyphTint: NetState.vpnUp ? Theme.green : Theme.fgDim
      title: NetState.vpnUp ? NetState.vpnActive.name : "NOT CONNECTED"
      sub: NetState.vpnUp ? "CONNECTED" : (NetState.vpnDefault() ? "NEXT: " + NetState.vpnDefault().name : "NO SAVED CONNECTION")
      highlight: NetState.vpnUp

      MiniButton {
        enabled: NetState.vpnUp || NetState.vpnDefault() !== null
        active: NetState.vpnUp
        text: NetState.vpnUp ? "DISCONNECT" : "CONNECT"
        onClicked: NetState.vpnToggle()
      }
    }

    MiniButton {
      text: "OPEN PROTON VPN"
      onClicked: Quickshell.execDetached(["uwsm", "app", "--"].concat(flick.protonCommand))
    }

    SectionHead { width: parent.width; text: "SAVED CONNECTIONS" }

    Repeater {
      model: NetState.vpns

      delegate: ConnectionRow {
        id: item

        required property var modelData

        readonly property bool isDefault: modelData.name === NetState.defaultVpn

        width: col.width
        glyph: Glyphs.vpn
        glyphTint: modelData.active ? Theme.green : Theme.fg
        title: modelData.name
        sub: (modelData.active ? "CONNECTED" : modelData.type.toUpperCase()) + (isDefault ? "   DEFAULT" : "")
        subTint: isDefault ? Theme.orange : Theme.fgDim
        highlight: modelData.active

        MiniButton {
          visible: !item.modelData.active
          text: "CONNECT"
          onClicked: NetState.vpnConnect(item.modelData.name)
        }

        MiniButton {
          visible: item.modelData.active
          text: "DISCONNECT"
          onClicked: NetState.vpnDisconnect()
        }

        MiniButton {
          text: "DEFAULT"
          active: item.isDefault
          onClicked: NetState.setDefaultVpn(item.modelData.name)
        }

        MiniButton {
          text: "FORGET"
          danger: true
          onClicked: NetState.vpnForget(item.modelData.name)
        }
      }
    }

    Rectangle {
      id: dropBox
      width: parent.width
      height: 64
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: dropArea.containsDrag ? Theme.orange : Theme.fgDim

      Text {
        anchors.centerIn: parent
        width: parent.width - 24
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: NetState.vpnError !== "" ? NetState.vpnError : Glyphs.upload + "   DROP A WIREGUARD .CONF OR OPENVPN .OVPN FILE HERE TO ADD IT"
        color: NetState.vpnError !== "" ? Theme.red : (dropArea.containsDrag ? Theme.orange : Theme.fgDim)
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }

      DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => NetState.vpnImport(drop.urls)
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "A NAME CAN HAVE AT MOST 15 CHARACTERS, LONGER ONES ARE CUT. ADDED CONNECTIONS DO NOT START BY THEMSELVES."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }
}
