pragma Singleton
import Quickshell

Singleton {
  property bool open: false
  property bool pinned: false
  property string screenName: ""     // monitor the launcher opened on: only that dock stays up for it
  property bool dockHidden: false     // the dock was hidden by hand; pinned windows hide with it
}
