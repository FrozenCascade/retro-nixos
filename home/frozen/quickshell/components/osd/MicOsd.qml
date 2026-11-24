import QtQuick
import Quickshell.Io
import qs

// The microphone indicator. It appears when the mic key in the bar changes the mic volume (wheel) or mutes
// it (middle click), not for every change: some apps adjust the mic by themselves and would keep it popping up.
// Same look as the volume indicator (the drawing is in OsdPopup), with the mic icon and an aqua bar.
OsdPopup {
  id: osd

  readonly property bool boosted: AudioState.micVolume > 1.001

  glyph: AudioState.micMuted ? Glyphs.micOff : Glyphs.mic
  glyphTint: AudioState.micMuted ? Theme.red : Theme.fg
  fraction: AudioState.micVolume / (boosted ? 1.5 : 1.0)
  fillColor: AudioState.micMuted ? Theme.fgDim : (boosted ? Theme.orange : Theme.aqua)
  label: AudioState.micMuted ? "MUTED" : Math.round(AudioState.micVolume * 100) + "%"
  labelTint: AudioState.micMuted ? Theme.red : Theme.fg
  namespace: "qs-osd-mic"

  // test it:  qs ipc call osd-mic show
  IpcHandler {
    target: "osd-mic"

    function show(): void {
      osd.show();
    }
  }

  Connections {
    target: AudioState

    function onMicPoked() {
      osd.poke();
    }
  }
}
