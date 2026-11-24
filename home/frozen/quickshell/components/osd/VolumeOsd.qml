import QtQuick
import Quickshell.Io
import qs

// The volume indicator. It appears when the output volume or mute changes (from the bar, the Audio window
// or a key). The bar ends at 100%, or at 150% while the volume is above 100%. The drawing is in OsdPopup.
OsdPopup {
  id: osd

  readonly property bool boosted: AudioState.volume > 1.001

  glyph: AudioState.icon
  glyphTint: AudioState.muted ? Theme.red : Theme.fg
  fraction: AudioState.volume / (boosted ? 1.5 : 1.0)
  fillColor: AudioState.muted ? Theme.fgDim : (boosted ? Theme.orange : Theme.blue)
  label: AudioState.muted ? "MUTED" : Math.round(AudioState.volume * 100) + "%"
  labelTint: AudioState.muted ? Theme.red : Theme.fg

  // test it without touching the volume:  qs ipc call osd show
  IpcHandler {
    target: "osd"

    function show(): void {
      osd.show();
    }
  }

  Connections {
    target: AudioState

    function onVolumeChanged() {
      osd.poke();
    }

    function onMutedChanged() {
      osd.poke();
    }
  }
}
