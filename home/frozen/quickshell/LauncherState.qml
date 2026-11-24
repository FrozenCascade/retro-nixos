pragma Singleton
import Quickshell

Singleton {
  property bool open: false
  property bool pinned: false
  property bool dockHidden: false     // the dock was hidden by hand; pinned windows hide with it
}
