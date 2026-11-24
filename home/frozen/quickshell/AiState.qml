pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The AI window. It is a separate little program (ai-browser/ in the repo) because Quickshell cannot
// host a web view itself yet: creating one aborts the whole shell. This singleton starts it, shows and
// hides it, and learns from the window whether it is showing (the window calls `qs ipc call ai state`).
Singleton {
  id: root

  property bool open: false

  function start() {
    return open;
  }

  // the colors the window should use, so it always matches the shell
  function themeJson() {
    return JSON.stringify({
      bg: Theme.bg.toString(), bgAlt: Theme.bgAlt.toString(), bgSel: Theme.bgSel.toString(),
      fg: Theme.fg.toString(), fgDim: Theme.fgDim.toString(),
      orange: Theme.orange.toString(), yellow: Theme.yellow.toString(), red: Theme.red.toString(),
      green: Theme.green.toString(), blue: Theme.blue.toString(), aqua: Theme.aqua.toString(),
      fontMono: Theme.fontMono, fontSize: Theme.fontSize,
      corner: Retro.corner, border: Retro.borderWidth, shadow: Retro.shadowOffset,
      shadowColor: Retro.shadowColor.toString(), inset: Retro.inset.toString()
    });
  }

  // first click starts the program (it shows itself); later clicks show or hide it
  function toggle() {
    Quickshell.execDetached([Tools.aiBrowser, "toggle", themeJson()]);
  }

  // the bar uses these so the AI window follows the same left/right/center rules as the other popups
  function show() {
    if (!open)
      toggle();
  }

  function hide() {
    if (open)
      toggle();
  }

  // end the AI program (and its browser) to give the memory back; the next click starts a fresh one
  function stop() {
    Quickshell.execDetached(["pkill", "-f", "ai-browser/browser.py"]);
    open = false;
  }

  // qs ipc call ai state true      (the window reports it)
  // qs ipc call ai stop            (ends the AI program to give its memory back)
  IpcHandler {
    target: "ai"
    function state(open: bool): void {
      root.open = open;
    }

    function stop(): void {
      root.stop();
    }
  }
}
