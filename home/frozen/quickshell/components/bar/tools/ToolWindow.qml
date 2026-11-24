import QtQuick
import qs
import qs.components.shared
import "../../../lib/nav.js" as Nav

// The frame every tool window (audio, session, ...) shares. All of them sit in the top right corner,
// so ONE Hyprland rule covers them: title "qs-tool-<name>", size frame + 4 px of shadow.
// Put the window's contents inside it; they fill `bodyWidth` x `bodyHeight`.
Item {
  id: root

  property string name: ""              // the window title becomes "qs-tool-<name>"
  property string title: ""
  property bool open: false
  property bool pinned: false
  property bool held: false

  signal closeRequested
  signal pinToggled
  signal opened
  signal keyPressed(var event)          // keys no control used; a window may react (set event.accepted)

  default property alias content: body.data
    readonly property alias window: frame.window

    property real frameWidth: 440         // a window can be wider (Session is)
    readonly property real frameHeight: 640
    readonly property real bodyWidth: frameWidth - 28
    readonly property real bodyHeight: frameHeight - 34 - 14

    onOpenChanged: {
      if (open)
        opened();
    }

    FramedWindow {
      id: frame
      windowTitle: "qs-tool-" + root.name
      title: root.title
      open: root.open
      pinned: root.pinned
      held: root.held
      frameWidth: root.frameWidth
      frameHeight: root.frameHeight
      onCloseRequested: root.closeRequested()
      onPinToggled: root.pinToggled()

      onKeyPressed: event => {
        if (event.key === Qt.Key_Escape) {
          if (!root.pinned)
            root.closeRequested();
          event.accepted = true;
          return;
        }
        root.keyPressed(event);
        if (!event.accepted && Nav.move(frame.panel, event))
          event.accepted = true;
      }

      Item {
        id: body
        x: 14
        y: 34
        width: root.bodyWidth
        height: root.bodyHeight
      }
    }
}
