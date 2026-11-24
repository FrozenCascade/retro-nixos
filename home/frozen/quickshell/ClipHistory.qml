pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history, read from cliphist (the watchers that fill it start with Hyprland).
// Deleting an entry hides it at once; the real delete happens when the undo time is over.
Singleton {
  id: root

  // newest first: { id, line, preview, isImage }
  property var entries: []
  property var hiddenIds: ({})          // ids waiting for their undo time to end
  property string signature: ""

  readonly property var shown: entries.filter(e => !hiddenIds[e.id])

  function refresh() {
    if (!lister.running)
      lister.running = true;
  }

  // "image/png" for an image entry, "" for text (wl-copy works that out itself)
  function mimeOf(entry) {
    if (!entry.isImage)
      return "";
    const m = /binary data .* (\w+) \d+x\d+/.exec(entry.preview);
    if (!m)
      return "";
    return "--type=image/" + (m[1] === "jpg" ? "jpeg" : m[1]);
  }

  function copy(entry) {
    Quickshell.execDetached(["sh", "-c", '"$1" decode "$2" | "$3" $4', "sh", Tools.cliphist, entry.id, Tools.wlCopy, mimeOf(entry)]);
  }

  function setHidden(id, hidden) {
    const h = Object.assign({}, hiddenIds);
    if (hidden)
      h[id] = true;
    else
      delete h[id];
    hiddenIds = h;
  }

  function remove(entry) {
    setHidden(entry.id, true);
    QuickUndo.stage("CLIPBOARD ENTRY", () => setHidden(entry.id, false), () => {
      Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | "$2" delete', "sh", entry.line, Tools.cliphist]);
      refreshSoon.restart();
    });
  }

  function wipe() {
    Quickshell.execDetached([Tools.cliphist, "wipe"]);
    entries = [];
    signature = "";
    refreshSoon.restart();
  }

  // stars an entry: keeps its full text in the quick window's own storage
  function pin(entry) {
    if (entry.isImage || decoder.running)
      return;
    decoder.wanted = entry.id;
    decoder.running = true;
  }

  Process {
    id: lister
    command: [Tools.cliphist, "list"]

    stdout: StdioCollector {
      onStreamFinished: {
        const out = [];
        for (const line of text.split("\n")) {
          const tab = line.indexOf("\t");
          if (tab < 0)
            continue;
          const preview = line.slice(tab + 1);
          out.push({
            id: line.slice(0, tab),
            line: line,
            preview: preview,
            isImage: preview.startsWith("[[ binary data")
          });
        }

        // only replace the list when something changed, so the view does not jump
        const latest = out.slice(0, 300);
        const sig = latest.map(e => e.id).join(",");
        if (sig !== root.signature) {
          root.signature = sig;
          root.entries = latest;
        }
      }
    }
  }

  Process {
    id: decoder
    property string wanted: ""
    command: [Tools.cliphist, "decode", wanted]

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          QuickStore.addSnippet(text);
      }
    }
  }

  Timer {
    id: refreshSoon
    interval: 400
    onTriggered: root.refresh()
  }
}
