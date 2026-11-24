import QtQuick
import qs

// What Studio puts in the bar: the song key and the play/pause key. ToolSection places it and adds the separator.
// `nameWidth` is the width of the song key; the bar computes it (see BarRight) so the title in the middle
// of the bar stays centered. fixedWidth is everything else here.
Row {
  id: group

  property bool open: false
  property real nameWidth: 160

  readonly property real fixedWidth: pause.width

  signal toggle

  spacing: 0

  StudioBarButton {
    anchors.verticalCenter: parent.verticalCenter
    width: group.nameWidth
    open: group.open
    hasPlayer: StudioState.player !== null
    recording: StudioRecorder.recording || StudioRecorder.obsRecording
    text: StudioState.label
    onClicked: group.toggle()
    onMiddleClicked: StudioRecorder.middleClick()
    onScrolled: dir => StudioState.cycle(-dir)
  }

  StudioPauseButton {
    id: pause
    anchors.verticalCenter: parent.verticalCenter
    playing: StudioState.playing
    muted: StudioState.muted
    enabled: StudioState.player !== null
    onClicked: StudioState.togglePlay()
    onMiddleClicked: StudioState.toggleMute()
    onScrolled: dir => StudioState.seekStep(dir)
  }
}
