import Quickshell
import Quickshell.Io
import QtQuick

// Reads a few small sysfs/proc files on a timer without starting a program for each reading.
//   find      a shell command that prints the files to read, one path per line (it runs once, at startup)
//   interval  milliseconds between readings
//   values    one number per file, refreshed every interval (empty until the files are found)
//   searched  true once `find` has finished; found: it printed at least one file
// Callers can fall back to something else when searched is true and found is false.
Scope {
  id: root

  property string find: ""
  property int interval: 3000
  property bool active: true

  property var values: []
  property bool searched: false
  readonly property bool found: readers.length > 0

  property var readers: []

  Component {
    id: reader

    FileView {
      blockLoading: true
    }
  }

  Process {
    id: finder
    command: ["sh", "-c", root.find]

    stdout: StdioCollector {
      onStreamFinished: {
        const made = [];
        for (const path of text.split("\n")) {
          if (path !== "")
            made.push(reader.createObject(root, { path: path }));
        }
        root.readers = made;
        root.searched = true;
      }
    }
  }

  function poll() {
    const out = [];
    for (const r of readers) {
      try {
        r.reload();
        out.push(parseFloat(r.text()) || 0);
      } catch (e) {
        out.push(0);                      // unreadable right now: count it as zero
      }
    }
    values = out;
  }

  Timer {
    interval: root.interval
    running: root.active && root.readers.length > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  Component.onCompleted: {
    if (find !== "")
      finder.running = true;
    else
      searched = true;
  }
}
