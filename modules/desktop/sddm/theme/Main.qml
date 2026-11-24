import QtQuick
import "style"

// The login screen: the lock screen's window with a user list (switch user) on the left, the photo,
// time and password in the middle, and the session list (which desktop to start) on the right.
// SDDM gives us `sddm`, `userModel` and `sessionModel`; the rest of the files in this folder are pieces.
Item {
  id: root

  // ---- what is chosen ----
  property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
  property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
  property string status: ""             // "", "checking" or "wrong"

  // Qt.UserRole is 256; SDDM's roles follow it (see UserModel.h / SessionModel.h)
  readonly property int roleUserName: 257
  readonly property int roleRealName: 258
  readonly property int roleIcon: 260
  readonly property int roleSessionName: 260

  function userField(role) {
    return userModel.data(userModel.index(userIndex, 0), role) || "";
  }

  readonly property string userName: userField(roleUserName)
  readonly property string realName: userField(roleRealName) || userName
  readonly property string iconPath: userField(roleIcon)
  readonly property string iconUrl: iconPath === "" ? "" : (iconPath.indexOf("://") > 0 ? iconPath : "file://" + iconPath)

  // sizes, matching the lock screen in the shell
  readonly property real pad: 16
  readonly property real sideWidth: 230
  readonly property real columnsHeight: 330

  function tryLogin() {
    if (password.text === "" || status === "checking")
      return;
    status = "checking";
    sddm.login(userName, password.text, sessionIndex);
  }

  Connections {
    target: sddm

    function onLoginFailed() {
      root.status = "wrong";
      password.text = "";
      password.forceActiveFocus();
    }
  }

  // ---- clock ----
  property date now: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  Backdrop {
    anchors.fill: parent
  }

  Item {
    id: card
    width: 900
    height: 36 + root.columnsHeight + 12 + 56 + root.pad
    anchors.centerIn: parent

    Rectangle {
      x: Skin.shadowOffset
      y: Skin.shadowOffset
      width: frame.width
      height: frame.height
      radius: Skin.corner
      color: Skin.shadow
    }

    Rectangle {
      id: frame
      width: card.width
      height: card.height
      radius: Skin.corner
      color: Skin.bg
      border.color: Skin.fg
      border.width: Skin.borderWidth

      // title bar: battery on the left, the name in the middle
      Rectangle {
        x: Skin.borderWidth
        y: Skin.borderWidth
        width: parent.width - Skin.borderWidth * 2
        height: 24
        color: Skin.fg

        BatteryReadout {
          anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        }

        Text {
          anchors.centerIn: parent
          text: "LOGIN"
          color: Skin.bg
          font.family: Skin.fontMono
          font.bold: true
          font.pointSize: Skin.fontSize - 1
        }
      }

      // ---- left: who ----
      PickList {
        x: root.pad
        y: 36
        width: root.sideWidth
        height: root.columnsHeight
        title: "SWITCH USER"
        model: userModel
        roleName: "realName"
        currentIndex: root.userIndex
        onPicked: index => {
          root.userIndex = index;
          root.status = "";
          password.text = "";
          password.forceActiveFocus();
        }
      }

      // ---- middle: photo, time, password ----
      Column {
        x: root.pad * 2 + root.sideWidth
        y: 36
        width: parent.width - (root.sideWidth + root.pad) * 2 - root.pad * 2
        spacing: 6

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 120
          height: 120
          radius: Skin.corner
          color: Skin.bgAlt
          border.width: Skin.borderWidth
          border.color: Skin.fg
          clip: true

          Image {
            id: avatar
            anchors.fill: parent
            anchors.margins: Skin.borderWidth
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            source: root.iconUrl
          }

          Text {
            anchors.centerIn: parent
            visible: avatar.status !== Image.Ready
            text: root.userName.charAt(0).toUpperCase()
            color: Skin.fgDim
            font.family: Skin.fontMono
            font.bold: true
            font.pointSize: Skin.fontSize + 22
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.realName.toUpperCase()
          color: Skin.fg
          font.family: Skin.fontMono
          font.bold: true
          font.pointSize: Skin.fontSize
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Qt.formatTime(root.now, "HH:mm")
          color: Skin.fg
          font.family: Skin.fontMono
          font.bold: true
          font.pointSize: Skin.fontSize * 3.4
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
          color: Skin.fgDim
          font.family: Skin.fontMono
          font.bold: true
          font.pointSize: Skin.fontSize - 1
          bottomPadding: 8
        }

        Rectangle {
          width: parent.width
          height: 36
          radius: Skin.corner
          color: Skin.inset
          border.width: Skin.borderWidth
          border.color: root.status === "wrong" ? Skin.red : (password.activeFocus ? Skin.yellow : Skin.fgDim)

          Text {
            anchors { fill: parent; leftMargin: 12 }
            verticalAlignment: Text.AlignVCenter
            visible: password.text === ""
            text: "PASSWORD"
            color: Skin.fgDim
            font.family: Skin.fontMono
            font.pointSize: Skin.fontSize
          }

          // shows while caps lock is on
          Rectangle {
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            visible: keyboard.capsLock
            width: capsLabel.implicitWidth + 12
            height: 22
            radius: Skin.corner
            color: Skin.orange

            Text {
              id: capsLabel
              anchors.centerIn: parent
              text: "CAPS"
              color: Skin.bg
              font.family: Skin.fontMono
              font.bold: true
              font.pointSize: Skin.fontSize - 1
            }
          }

          TextInput {
            id: password
            anchors { fill: parent; leftMargin: 12; rightMargin: keyboard.capsLock ? 62 : 12 }
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            passwordCharacter: "*"
            color: Skin.fg
            enabled: root.status !== "checking"
            font.family: Skin.fontMono
            font.pointSize: Skin.fontSize + 1
            focus: true
            onAccepted: root.tryLogin()
            Component.onCompleted: forceActiveFocus()
          }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.status === "wrong" ? "WRONG PASSWORD" : (root.status === "checking" ? "LOGGING IN..." : "ENTER TO LOG IN")
          color: root.status === "wrong" ? Skin.red : Skin.fgDim
          font.family: Skin.fontMono
          font.bold: true
          font.pointSize: Skin.fontSize - 1
        }
      }

      // ---- right: which desktop ----
      PickList {
        x: parent.width - root.pad - root.sideWidth
        y: 36
        width: root.sideWidth
        height: root.columnsHeight
        title: "DESKTOP"
        model: sessionModel
        roleName: "name"
        currentIndex: root.sessionIndex
        onPicked: index => {
          root.sessionIndex = index;
          password.forceActiveFocus();
        }
      }

      PowerRow {
        x: root.pad
        y: 36 + root.columnsHeight + 12
        width: parent.width - root.pad * 2
      }
    }
  }
}
