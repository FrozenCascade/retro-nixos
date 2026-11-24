pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// What the quick window remembers: notes, starred clipboard snippets and starred layouts.
// Saved as readable JSON in Quickshell's state folder (quick.json).
Singleton {
  id: root

  // a note: { id, text, pinned, font, size, updated }   (font "" and size 0 mean the defaults)
  property var notes: []
  // a clipboard entry you starred: { id, text }
  property var snippets: []
  // layouts you starred, by short name ("US", "QA")
  property var pinnedLayouts: []

  // ---- small helpers ----
  function uid() {
    return Date.now().toString(36) + Math.floor(Math.random() * 1679616).toString(36);
  }

  function textLines(text) {
    return String(text || "").split("\n").map(s => s.trim()).filter(s => s !== "");
  }

  function noteTitle(note) {
    const l = textLines(note.text);
    return l.length > 0 ? l[0] : "(empty note)";
  }

  function notePreview(note) {
    return textLines(note.text).slice(1).join("  ");
  }

  // one line, cut to a length, for labels
  function brief(text, max) {
    const s = String(text || "").replace(/\s+/g, " ").trim();
    return s.length > max ? s.slice(0, max - 1) + "…" : s;
  }

  // ---- notes ----
  function noteById(id) {
    return root.notes.find(n => n.id === id);
  }

  function newNote(text) {
    const n = {
      id: uid(),
      text: text || "",
      pinned: false,
      font: "",
      size: 0,
      updated: Date.now()
    };
    notes = [n].concat(notes);
    changed();
    return n.id;
  }

  function updateNote(id, patch) {
    const old = noteById(id);
    if (!old)
      return;
    // nothing really changed: leave the note (and its place in the list) alone
    if (Object.keys(patch).length === 1 && patch.text !== undefined && patch.text === old.text)
      return;
    notes = notes.map(n => n.id === id ? Object.assign({}, n, patch, {
      updated: Date.now()
    }) : n);
    changed();
  }

  function toggleNotePin(id) {
    const n = noteById(id);
    if (n)
      updateNote(id, {
        pinned: !n.pinned
      });
  }

  function removeNote(id) {
    notes = notes.filter(n => n.id !== id);
    changed();
  }

  function removeNotes(ids) {
    notes = notes.filter(n => ids.indexOf(n.id) === -1);
    changed();
  }

  // puts a deleted note back exactly as it was
  function restoreNote(note) {
    if (noteById(note.id))
      return;
    notes = notes.concat([note]);
    changed();
  }

  function clearNotes() {
    notes = [];
    changed();
  }

  // ---- starred clipboard entries ----
  function addSnippet(text) {
    if (snippets.some(s => s.text === text))
      return;
    snippets = [
      {
        id: uid(),
        text: text
      }
    ].concat(snippets);
    changed();
  }

  function removeSnippet(id) {
    snippets = snippets.filter(s => s.id !== id);
    changed();
  }

  function restoreSnippet(snippet) {
    if (snippets.some(s => s.id === snippet.id))
      return;
    snippets = [snippet].concat(snippets);
    changed();
  }

  // ---- starred layouts ----
  function isLayoutPinned(short) {
    return pinnedLayouts.indexOf(short) !== -1;
  }

  function toggleLayoutPin(short) {
    if (isLayoutPinned(short))
      pinnedLayouts = pinnedLayouts.filter(s => s !== short);
    else
      pinnedLayouts = pinnedLayouts.concat([short]);
    changed();
  }

  // ---- saving and loading ----
  property bool writable: true

  function load(raw) {
    if (String(raw).trim() === "")
      return;

    try {
      const d = JSON.parse(raw);
      notes = Array.isArray(d.notes) ? d.notes : [];
      snippets = Array.isArray(d.snippets) ? d.snippets : [];
      pinnedLayouts = Array.isArray(d.pinnedLayouts) ? d.pinnedLayouts : [];
    } catch (e) {
      // leave the file alone rather than overwrite something we could not read
      writable = false;
      console.warn("quick.json could not be read, so notes will not be saved: " + e);
    }
  }

  function changed() {
    saveTimer.restart();
  }

  function saveNow() {
    saveTimer.stop();
    if (!writable)
      return;
    file.setText(JSON.stringify({
      notes: notes,
      snippets: snippets,
      pinnedLayouts: pinnedLayouts
    }, null, 1));
  }

  FileView {
    id: file
    path: Quickshell.statePath("quick.json")
    // written on the spot, not on a background thread: the last save happens while the shell shuts down,
    // and an asynchronous write there crashes it
    blockWrites: true
    onLoaded: root.load(file.text())
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: root.saveNow()
  }

  Component.onDestruction: root.saveNow()
}
