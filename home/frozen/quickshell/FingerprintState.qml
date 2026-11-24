pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Your fingerprints, through fprintd (the same service KDE uses): which fingers are saved, adding one
// (the reader asks for several touches) and removing one. The lock screen also reads `enrolled`.
Singleton {
  id: root

  readonly property string user: Quickshell.env("USER")

  // fprintd's tools come from services.fprintd (modules/system/fingerprint.nix), so they sit in the system profile
  readonly property string bin: "/run/current-system/sw/bin"

  property bool available: false          // a reader was found
  property var enrolled: []               // finger ids that have a saved print
  property string enrolling: ""           // the finger being added right now
  property int scans: 0                   // good touches so far while adding
  property string message: ""             // what to tell the person

  // every finger fprintd knows, grouped for the panel
  readonly property var hands: [
    { name: "LEFT", fingers: [
      { id: "left-thumb", label: "THUMB" },
      { id: "left-index-finger", label: "INDEX" },
      { id: "left-middle-finger", label: "MIDDLE" },
      { id: "left-ring-finger", label: "RING" },
      { id: "left-little-finger", label: "LITTLE" }
    ] },
    { name: "RIGHT", fingers: [
      { id: "right-thumb", label: "THUMB" },
      { id: "right-index-finger", label: "INDEX" },
      { id: "right-middle-finger", label: "MIDDLE" },
      { id: "right-ring-finger", label: "RING" },
      { id: "right-little-finger", label: "LITTLE" }
    ] }
  ]

  function has(id) {
    return enrolled.indexOf(id) !== -1;
  }

  function refresh() {
    list.running = true;
  }

  function enroll(id) {
    if (enrolling !== "" || !available)
      return;
    scans = 0;
    message = "PLACE THE FINGER ON THE READER";
    enrolling = id;
    add.command = [bin + "/fprintd-enroll", "-f", id, user];
    add.running = true;
  }

  function cancel() {
    if (add.running)
      add.signal(2);
  }

  function remove(id) {
    if (enrolling !== "")
      return;
    erase.command = [bin + "/fprintd-delete", "-f", id, user];
    erase.running = true;
  }

  // one line of fprintd-enroll's output, e.g. "Enroll result: enroll-stage-passed"
  function onEnrollLine(line) {
    const m = /Enroll result: (\S+)/.exec(line);
    if (!m)
      return;
    const r = m[1];
    if (r === "enroll-stage-passed") {
      scans += 1;
      message = scans + " GOOD. LIFT AND TOUCH AGAIN";
    } else if (r === "enroll-completed") {
      message = "SAVED";
    } else if (r === "enroll-failed" || r === "enroll-data-full" || r === "enroll-disconnected" || r === "enroll-unknown-error") {
      message = "FAILED. TRY AGAIN";
    } else {
      message = "TRY AGAIN: TOUCH THE READER FLAT AND STEADY";   // retry, swipe too short, off centre...
    }
  }

  Process {
    id: list
    command: [bin + "/fprintd-list", root.user]
    stdout: StdioCollector {
      onStreamFinished: {
        root.available = /found \d+ device/i.test(text);
        const found = [];
        const re = /#\d+: ([a-z-]+)/g;
        let m;
        while ((m = re.exec(text)) !== null)
          found.push(m[1]);
        root.enrolled = found;
      }
    }
  }

  Process {
    id: add
    stdout: SplitParser {
      onRead: line => root.onEnrollLine(line)
    }
    onExited: {
      root.enrolling = "";
      root.refresh();
    }
  }

  Process {
    id: erase
    onExited: root.refresh()
  }

  Component.onCompleted: refresh()
}
