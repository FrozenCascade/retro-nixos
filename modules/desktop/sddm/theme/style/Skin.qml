pragma Singleton
import QtQuick

// REPLACED at build time by modules/desktop/sddm.nix (named Skin because QtQuick already has a built-in type called Palette) with your Stylix colours. These are plain gruvbox
// values so the theme still draws if you test it with `sddm-greeter-qt6 --test-mode --theme <folder>`.
QtObject {
  readonly property color bg: "#282828"
  readonly property color bgAlt: "#3c3836"
  readonly property color bgSel: "#504945"
  readonly property color fgDim: "#928374"
  readonly property color fg: "#ebdbb2"
  readonly property color red: "#fb4934"
  readonly property color orange: "#fe8019"
  readonly property color yellow: "#fabd2f"
  readonly property string fontMono: "BlexMono Nerd Font"
  readonly property real fontSize: 11

  // the shell's Retro.qml, repeated here because the greeter cannot see the shell
  readonly property real corner: 3
  readonly property real shadowOffset: 4
  readonly property real borderWidth: 2
  readonly property color shadow: Qt.rgba(0, 0, 0, 0.6)
  readonly property color inset: Qt.rgba(0, 0, 0, 0.35)
}
