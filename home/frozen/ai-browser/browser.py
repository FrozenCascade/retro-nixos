"""The AI window: a small Qt program with a browser inside (Duck AI, Perplexity, Claude).

Quickshell cannot host a WebEngineView itself yet (it aborts the whole shell), so this runs as its
own process. The bar button starts it through the qs-ai-browser wrapper (see quickshell.nix) and later
clicks send it SIGUSR1, which shows or hides the window. The program keeps running while hidden, so
the conversation is still there when it comes back. Logins and cookies live in ~/.local/share/qs-ai.

Run `qs-ai-browser` in a terminal to see its messages if something goes wrong.
"""
import json
import os
import signal
import subprocess
import sys

from PySide6.QtCore import QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWebEngineQuick import QtWebEngineQuick

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "qs-ai")


def quiet(cmd):
    try:
        subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        print("could not run", cmd[0], err, file=sys.stderr)


class Bridge(QObject):
    toggleRequested = Signal()

    @Slot(bool)
    def report(self, showing):
        """Tell the bar button whether the window is showing."""
        quiet(["qs", "ipc", "call", "ai", "state", "true" if showing else "false"])

    @Slot(str)
    def openExternal(self, url):
        """Open a page in your normal browser (for logins an embedded browser may be refused)."""
        quiet(["xdg-open", url])


def main():
    theme = sys.argv[2] if len(sys.argv) > 2 else "{}"
    try:
        json.loads(theme)
    except ValueError:
        theme = "{}"

    QtWebEngineQuick.initialize()          # must come before the application is created
    app = QGuiApplication(sys.argv[:1])
    app.setApplicationName("qs-ai")
    app.setOrganizationName("qs-config")
    app.setDesktopFileName("qs-ai")
    os.makedirs(DATA, exist_ok=True)

    bridge = Bridge()
    engine = QQmlApplicationEngine()
    engine.quit.connect(app.quit)          # Qt.quit() in main.qml ends the program
    ctx = engine.rootContext()
    ctx.setContextProperty("bridge", bridge)
    ctx.setContextProperty("themeJson", theme)
    ctx.setContextProperty("dataDir", DATA)
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "main.qml")))
    if not engine.rootObjects():
        sys.exit(1)

    # Python only runs its signal handlers while it is executing, so give it a tick to do that
    signal.signal(signal.SIGUSR1, lambda *_: bridge.toggleRequested.emit())
    tick = QTimer()
    tick.timeout.connect(lambda: None)
    tick.start(200)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
