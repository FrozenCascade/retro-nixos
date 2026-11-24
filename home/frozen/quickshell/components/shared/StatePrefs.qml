import Quickshell
import Quickshell.Io
import QtQuick

// A small JSON file in Quickshell's state folder, saved a moment after the last change.
// The owner puts the values to keep in `data`, calls save() after changing them, and reads them back
// in onLoaded. A file that cannot be read is left alone.
//
//   StatePrefs {
//     id: prefs
//     file: "thing.json"
//     data: ({ size: root.size })
//     onLoaded: saved => root.size = saved.size || 10
//   }
Item {
  id: prefs

  property string file: ""
  property var data: ({})

  signal loaded(var saved)

  function save() {
    wait.restart();
  }

  Timer {
    id: wait
    interval: 500
    onTriggered: view.setText(JSON.stringify(prefs.data))
  }

  FileView {
    id: view
    path: prefs.file !== "" ? Quickshell.statePath(prefs.file) : ""
    onLoaded: {
      try {
        prefs.loaded(JSON.parse(view.text()));
      } catch (e) {}
    }
  }
}
