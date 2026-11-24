pragma Singleton
import Quickshell
import QtQuick

// "Deleted. Undo" for the quick window.
// stage() lets something disappear now and remembers how to bring it back (undo) and how to make
// the deletion final (commit). It becomes final when the timer ends or when another deletion
// starts. Pressing Undo first cancels it.
Singleton {
  id: root

  readonly property int seconds: 7
  property var pending: null            // { label, undo, commit } or null

  function stage(label, undo, commit) {
    finalize();
    pending = {
      label: label,
      undo: undo,
      commit: commit
    };
    timer.restart();
  }

  function undo() {
    if (pending === null)
      return;
    const p = pending;
    pending = null;
    timer.stop();
    if (p.undo)
      p.undo();
  }

  function finalize() {
    if (pending === null)
      return;
    const p = pending;
    pending = null;
    timer.stop();
    if (p.commit)
      p.commit();
  }

  Timer {
    id: timer
    interval: root.seconds * 1000
    onTriggered: root.finalize()
  }
}
