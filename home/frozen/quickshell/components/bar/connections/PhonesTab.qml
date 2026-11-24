import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar
import "../../../lib/net.js" as Net

// The PHONES tab (KDE Connect), so the KDE Connect app is not needed: pair and unpair, answer a pairing request
// from the phone, and for the picked phone ping, ring, send the clipboard, text or a link, an SMS, open its
// files, and send files by dropping them on the box at the bottom. Also what arrived lately.
Item {
  id: page

  property bool active: false

  // the list refreshes while this tab shows
  onActiveChanged: {
    if (active)
      NetState.refreshPhones();
  }

  Timer {
    interval: 8000
    repeat: true
    running: page.active && NetState.watching
    onTriggered: NetState.refreshPhones()
  }

  // the picked phone is paired and online
  readonly property bool canAct: NetState.phone !== null && NetState.phone.paired && NetState.phone.reachable

  function kindGlyph(type) {
    return type === "tablet" ? Glyphs.tablet : (type === "laptop" || type === "desktop" ? Glyphs.laptop : Glyphs.phone);
  }

  Flickable {
    id: flick
    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: dropBox.top; bottomMargin: 8 }
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 8
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: flick.width
      spacing: 8

      SectionHead { width: parent.width; text: "DEVICES" }

      Text {
        visible: NetState.phones.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: "NO DEVICES. OPEN KDE CONNECT ON THE PHONE, ON THE SAME NETWORK."
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }

      // the rows follow phoneIds, so they stay put while the data inside them updates
      Repeater {
        model: NetState.phoneIds

        delegate: ConnectionRow {
          id: item

          required property string modelData

          readonly property var d: NetState.phoneById(modelData) || { id: modelData, name: "", paired: false, reachable: false, type: "", charge: -1, pairRequested: false }

          width: col.width
          glyph: page.kindGlyph(d.type)
          glyphTint: d.reachable ? Theme.fg : Theme.fgDim
          title: d.name
          sub: (d.paired ? "PAIRED" : (d.pairRequested ? "WANTS TO PAIR" : "NOT PAIRED")) + (d.reachable ? "   ONLINE" : "   OFFLINE") + (d.charge >= 0 ? "   BATTERY " + d.charge + "%" : "")
          subTint: d.pairRequested && !d.paired ? Theme.orange : Theme.fgDim
          highlight: d.id === NetState.phoneId
          onClicked: NetState.phoneId = d.id

          MiniButton {
            visible: !item.d.paired && !item.d.pairRequested
            enabled: item.d.reachable
            text: "PAIR"
            onClicked: NetState.phoneDo(item.d.id, "--pair")
          }

          MiniButton {
            visible: !item.d.paired && item.d.pairRequested
            text: "ACCEPT"
            active: true
            onClicked: NetState.phonePairAnswer(item.d.id, true)
          }

          MiniButton {
            visible: !item.d.paired && item.d.pairRequested
            text: "REJECT"
            danger: true
            onClicked: NetState.phonePairAnswer(item.d.id, false)
          }

          MiniButton {
            visible: item.d.paired
            text: "UNPAIR"
            danger: true
            onClicked: NetState.phoneDo(item.d.id, "--unpair")
          }
        }
      }

      // ---- what to do with the picked phone ----
      SectionHead { visible: page.canAct; width: parent.width; text: "ACTIONS" }

      Flow {
        visible: page.canAct
        width: parent.width
        spacing: 6

        MiniButton { text: "PING"; onClicked: NetState.phoneDo(NetState.phoneId, "--ping") }
        MiniButton { text: "RING"; onClicked: NetState.phoneDo(NetState.phoneId, "--ring") }
        MiniButton { text: "SEND CLIPBOARD"; onClicked: NetState.phoneDo(NetState.phoneId, "--send-clipboard") }
        MiniButton { text: "OPEN FILES"; onClicked: NetState.phoneFiles(NetState.phoneId) }
      }

      Row {
        visible: page.canAct
        width: parent.width
        spacing: 6

        FieldBox {
          id: textBox
          width: parent.width - sendText.width - 6
          placeholder: "TEXT OR LINK FOR THE PHONE"
          onAccepted: sendText.go()
        }

        MiniButton {
          id: sendText
          text: "SEND"

          function go() {
            NetState.phoneShareText(NetState.phoneId, textBox.text);
            textBox.text = "";
          }

          onClicked: go()
        }
      }

      Row {
        visible: page.canAct
        width: parent.width
        spacing: 6

        FieldBox {
          id: smsNumber
          width: 110
          placeholder: "NUMBER"
        }

        FieldBox {
          id: smsText
          width: parent.width - 110 - sendSms.width - 12
          placeholder: "SMS TEXT"
          onAccepted: sendSms.go()
        }

        MiniButton {
          id: sendSms
          text: "SMS"

          function go() {
            NetState.phoneSms(NetState.phoneId, smsNumber.text, smsText.text);
            smsText.text = "";
          }

          onClicked: go()
        }
      }

      SectionHead { width: parent.width; text: "RECEIVED (24 H)" }

      Text {
        visible: NetState.received.length === 0
        text: "NOTHING LATELY"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }

      Repeater {
        model: NetState.received

        delegate: Item {
          required property var modelData

          width: col.width
          height: 20

          Text {
            anchors { left: parent.left; right: age.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            elide: Text.ElideMiddle
            text: parent.modelData.name
            color: Theme.fg
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 2
          }

          Text {
            id: age
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: Net.ago(Date.now() / 1000 - parent.modelData.time)
            color: Theme.fgDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontSize - 2
          }
        }
      }
    }
  }

  // ---- drop files here to send them to the picked phone ----
  readonly property bool canSend: canAct

  Rectangle {
    id: dropBox
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 64
    radius: Retro.corner
    color: Retro.inset
    border.width: Retro.borderWidth
    border.color: dropArea.containsDrag && page.canSend ? Theme.orange : Theme.fgDim
    opacity: page.canSend ? 1 : 0.5

    Text {
      anchors.centerIn: parent
      width: parent.width - 24
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: page.canSend ? Glyphs.upload + "   DROP FILES HERE TO SEND TO " + NetState.phone.name.toUpperCase() : "PICK A PAIRED, ONLINE PHONE TO SEND FILES"
      color: dropArea.containsDrag && page.canSend ? Theme.orange : Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    DropArea {
      id: dropArea
      anchors.fill: parent
      keys: ["text/uri-list"]
      onDropped: drop => {
        if (page.canSend)
          NetState.sendFiles(NetState.phoneId, drop.urls);
      }
    }
  }
}
