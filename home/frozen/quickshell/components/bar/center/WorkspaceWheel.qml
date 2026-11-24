import QtQuick
import qs

// Scrolling steps through the workspaces: up = the previous one, down = the next one (wrapping around).
// Put one inside a button or a section and call handle() from the onWheel of the MouseArea there:
//
//   WorkspaceWheel { id: stepper; workspace: bar.wsName }
//   MouseArea { onWheel: wheel => stepper.handle(wheel) }
QtObject {
  id: stepper

  property string workspace: ""        // the workspace being shown now
  property real accumulated: 0

  // waits for a full notch (touchpads send many small steps)
  function handle(wheel) {
    wheel.accepted = true;
    accumulated += wheel.angleDelta.y;
    if (Math.abs(accumulated) < 120)
      return;
    const delta = accumulated > 0 ? -1 : 1;
    accumulated = 0;
    Desktop.stepWorkspace(workspace, delta);
  }
}
