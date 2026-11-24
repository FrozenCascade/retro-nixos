import QtQuick
import qs

// The numbered workspace buttons (1 .. Settings.workspaceCount). The laptop workspace has its own
// key and is not shown here. How a button looks is in WorkspaceButton.qml.
Row {
  id: row

  property string current: ""           // the workspace this monitor is showing
  property var focusedWindow: null      // the window a middle click brings to a workspace

  spacing: 2

  Repeater {
    model: Settings.workspaceCount

    WorkspaceButton {
      required property int index
      name: String(index + 1)
      current: row.current
      focusedWindow: row.focusedWindow
    }
  }
}
