import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import qs

// The lock screen. Lock with the Lock button in the Session window, `qs ipc call lock lock`, or let
// hypridle do it after 5 idle minutes. Your password is checked by PAM (the "quickshell-lock" service
// that quickshell.nix / the NixOS config creates).
//
// Locked out while testing? From a text console (Ctrl+Alt+F3) run:  qs ipc call lock unlock
// Delete the unlock() function below once you trust the lock.
Scope {
  id: root

  property string typed: ""
  property string status: ""            // "", "checking" or "wrong"

  signal cleared

  function submit(password) {
    if (password === "" || pam.active)
      return;
    typed = password;
    status = "checking";
    pam.start();
  }

  PamContext {
    id: pam
    config: "quickshell-lock"

    onPamMessage: {
      if (responseRequired)
        respond(root.typed);
    }

    onCompleted: result => {
      root.typed = "";
      root.cleared();
      if (result === PamResult.Success) {
        root.status = "";
        LockState.locked = false;
        Sounds.play("unlock");
      } else {
        root.status = "wrong";
      }
    }
  }

  // ---- fingerprint: its own PAM service, so the password box never waits for the reader ----
  readonly property bool fingerprintReady: FingerprintState.available && FingerprintState.enrolled.length > 0
  property string fingerprintHint: ""

  onFingerprintReadyChanged: listen()

  function listen() {
    if (LockState.locked && fingerprintReady && !fingerprint.active)
      fingerprint.start();
  }

  PamContext {
    id: fingerprint
    config: "quickshell-lock-fprint"

    onPamMessage: root.fingerprintHint = message

    onCompleted: result => {
      if (result === PamResult.Success) {
        root.status = "";
        LockState.locked = false;
        Sounds.play("unlock");
      } else {
        retry.restart();                 // too many bad scans: wait a moment, then listen again
      }
    }
  }

  Timer {
    id: retry
    interval: 1500
    onTriggered: root.listen()
  }

  Connections {
    target: LockState

    function onLockedChanged() {
      if (LockState.locked) {
        FingerprintState.refresh();      // the list may be older than the last enroll or delete
        root.listen();
      } else {
        fingerprint.abort();
      }
    }
  }

  IpcHandler {
    target: "lock"


    function sleep(): void {
      LockState.lockAndSuspend();
    }
    function lock(): void {
      LockState.locked = true;
    }

    function unlock(): void {
      LockState.locked = false;
    }
  }

  WlSessionLock {
    id: lock
    locked: LockState.locked
    onSecureChanged: LockState.secure = secure
    onLockedChanged: {
      if (locked)
        root.status = "";
    }

    WlSessionLockSurface {
      id: lockSurface
      color: Theme.bg

      LockSurface {
        anchors.fill: parent
        screenName: lockSurface.screen ? lockSurface.screen.name : ""
        controller: root
      }
    }
  }
}
