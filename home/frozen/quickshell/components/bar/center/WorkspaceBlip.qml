import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// A split-second label in the middle of the screen whenever the workspace changes: 一 / Yī - 1
// No frame, no input: the window is always there but click-through and invisible, and the text
// lights up for holdMs.
PanelWindow {
  id: blip

  property string workspace: ""          // the workspace the monitor is showing now

  readonly property int holdMs: 100      // how long it stays: 100 = a tenth of a second
  property string lastWorkspace: ""
  property bool lit: false

  // above everything, click-through, takes no space and never takes the keyboard
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "workspace-blip"
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}
  color: "transparent"

  implicitWidth: 520
  implicitHeight: 170

  onWorkspaceChanged: {
    if (workspace === "")
      return;
    // the first value after the shell starts is not a switch
    if (lastWorkspace !== "" && lastWorkspace !== workspace) {
      lit = true;
      hideTimer.restart();
    }
    lastWorkspace = workspace;
  }

  Timer {
    id: hideTimer
    interval: blip.holdMs
    onTriggered: blip.lit = false
  }

  // "一 / Yī - 1", "~ / Laptop"
  readonly property string readingText: {
    const r = Desktop.reading(workspace);
    return "/ " + (r !== "" ? r + "  " : "") + "- " + Desktop.label(workspace);
  }

  // The label is drawn twice: first as a hard dark shadow, then the real one on top of it.
  component Label: Row {
    property color tint: Theme.fg
    property string glyph: ""
    property string readingText: ""
    spacing: 22

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: parent.glyph
      color: parent.tint
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize * 6
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: parent.readingText
      color: parent.tint
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize * 2.4
    }
  }

  Item {
    anchors.fill: parent
    visible: blip.lit

    Label {
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: Retro.shadowOffset
      anchors.verticalCenterOffset: Retro.shadowOffset
      tint: Retro.shadowColor
      glyph: Desktop.glyph(blip.workspace)
      readingText: blip.readingText
    }

    Label {
      anchors.centerIn: parent
      tint: Theme.fg
      glyph: Desktop.glyph(blip.workspace)
      readingText: blip.readingText
    }
  }
}
