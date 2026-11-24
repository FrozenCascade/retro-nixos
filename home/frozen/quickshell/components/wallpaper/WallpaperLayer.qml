import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// The wallpaper: one window per monitor on the background layer, behind every other window.
// It shows the monitor's picture, the mode picked for it (blank, desktop, music, matrix, snake) and the
// decor in front of the picture. Only the active mode is loaded, so the others cost nothing.
// Settings and the mode list are in WallpaperState; the controls are the WALLPAPER tab of the Display window.
Scope {
  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: layer

      required property var modelData

      readonly property string mode: WallpaperState.modeOf(modelData.name)
      readonly property var cfg: WallpaperState.cfg(modelData.name)

      // blank ignores the pointer; the other modes handle it themselves
      readonly property bool passive: mode === "blank"

      screen: modelData
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      exclusionMode: ExclusionMode.Ignore
      color: Theme.bg
      mask: passive ? clickThrough : null

      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "qs-wallpaper"
      // snake reads keys, but only after you click the wallpaper
      WlrLayershell.keyboardFocus: mode === "snake" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      Region {
        id: clickThrough
      }

      // the picture (matrix paints its own background, so the picture is not even loaded then)
      Image {
        anchors.fill: parent
        visible: layer.mode !== "matrix"
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(layer.modelData.width, layer.modelData.height)
        source: layer.mode !== "matrix" ? WallpaperState.fileUrl(layer.modelData.name) : ""
      }

      // rain: over the picture and under the mode (matrix paints its own background, so it would be hidden)
      Loader {
        anchors.fill: parent
        active: layer.cfg.rain && layer.mode !== "matrix"
        sourceComponent: rainLayer
      }

      Loader {
        anchors.fill: parent
        sourceComponent: ({
          desktop: desktopMode,
          music: musicMode,
          matrix: matrixMode,
          snake: snakeMode
        })[layer.mode] || null
      }

      // (no decor layer: the audio bars live in the music mode only)

      Component {
        id: rainLayer
        RainLayer { monitorName: layer.modelData ? layer.modelData.name : "" }
      }

      Component {
        id: desktopMode
        DesktopMode { monitorName: layer.modelData ? layer.modelData.name : "" }
      }

      Component {
        id: musicMode
        MusicMode { monitorName: layer.modelData ? layer.modelData.name : "" }
      }

      Component {
        id: matrixMode
        MatrixMode { monitorName: layer.modelData ? layer.modelData.name : "" }
      }

      Component {
        id: snakeMode
        SnakeMode { monitorName: layer.modelData ? layer.modelData.name : "" }
      }
    }
  }
}
