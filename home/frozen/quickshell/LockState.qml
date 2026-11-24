pragma Singleton
import Quickshell
import QtQuick

// Whether the screen is locked. The lock screen (components/lock) draws it; everything else just sets `locked`.
Singleton {
  id: root

  property bool locked: false
  property bool secure: false           // the compositor confirms every screen is covered
  property bool suspendWhenSecure: false

  // lock first, and only suspend once the lock is really in place, so waking up shows the lock
  function lockAndSuspend() {
    if (locked && secure) {
      suspend();
      return;
    }
    suspendWhenSecure = true;
    locked = true;
  }

  function suspend() {
    suspendWhenSecure = false;
    Quickshell.execDetached(["systemctl", "suspend"]);
  }

  // Unlocking is not input for hypridle, so after a lock it would stay "idle" and never lock again.
  // Restarting it gives fresh idle timers.
  onLockedChanged: {
    if (locked)
      Sounds.play("lock");
    else
      Quickshell.execDetached(["systemctl", "--user", "restart", "hypridle"]);
  }

  onSecureChanged: {
    if (secure && suspendWhenSecure)
      suspend();
  }
}
