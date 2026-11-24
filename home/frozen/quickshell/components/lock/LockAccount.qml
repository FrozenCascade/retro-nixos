import QtQuick
import qs
import "../../lib/calendar.js" as Cal

// Middle of the lock window: your photo, the time and the password box.
Item {
  id: root

  required property var controller

  property real photoSize: 120          // the photo takes the space the password box leaves free

  function refocus() {
    input.text = "";
    input.forceActiveFocus();
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width
    spacing: 6

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.photoSize
      height: root.photoSize
      radius: Retro.corner
      color: Theme.bgAlt
      border.width: Retro.borderWidth
      border.color: Theme.fg
      clip: true

      Image {
        id: avatar
        anchors.fill: parent
        anchors.margins: Retro.borderWidth
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        source: SessionState.avatarUrl
      }

      Text {
        anchors.centerIn: parent
        visible: avatar.status !== Image.Ready
        text: SessionState.user.charAt(0).toUpperCase()
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize + 22
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: SessionState.user + "@" + SessionState.host
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: Clock.hh + ":" + Clock.mm
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize * 3.4
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: Cal.dayLabel(Clock.todayDn)
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
      bottomPadding: 8
    }

    Rectangle {
      width: parent.width
      height: 36
      radius: Retro.corner
      color: Retro.inset
      border.width: Retro.borderWidth
      border.color: root.controller.status === "wrong" ? Theme.red : (input.activeFocus ? Theme.yellow : Theme.fgDim)

      Text {
        anchors { fill: parent; leftMargin: 12 }
        verticalAlignment: Text.AlignVCenter
        visible: input.text === ""
        text: "PASSWORD"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize
      }

      // shows while caps lock is on
      Rectangle {
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        visible: KeyboardState.capsLock
        width: capsLabel.implicitWidth + 12
        height: 22
        radius: Retro.corner
        color: Theme.orange

        Text {
          id: capsLabel
          anchors.centerIn: parent
          text: "CAPS"
          color: Theme.bg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }
      }

      TextInput {
        id: input
        anchors { fill: parent; leftMargin: 12; rightMargin: KeyboardState.capsLock ? 62 : 12 }
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        passwordCharacter: "*"
        color: Theme.fg
        focus: true
        enabled: root.controller.status !== "checking"
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize + 1
        onAccepted: root.controller.submit(text)
        Component.onCompleted: forceActiveFocus()
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.controller.status === "wrong" ? "WRONG PASSWORD" : (root.controller.status === "checking" ? "CHECKING..." : (root.controller.fingerprintReady ? "PASSWORD OR FINGERPRINT" : "ENTER TO UNLOCK"))
      color: root.controller.status === "wrong" ? Theme.red : Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }
  }
}
