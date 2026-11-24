import Quickshell
import qs
import QtQuick
import qs.components.bar
import qs.components.bar.studio
import qs.components.dock
import qs.components.launcher
import qs.components.lock
import qs.components.notifications
import qs.components.display
import qs.components.osd
import qs.components.wallpaper

Scope {
  // The top bar lives on this monitor when it is connected,
  // otherwise on the first monitor that remains.
  readonly property string barMonitor: Settings.externalMonitor

  readonly property var barScreens: {
    const all = Array.from(Quickshell.screens);
    const preferred = all.filter(s => s.name === barMonitor);
    return preferred.length > 0 ? preferred : all.slice(0, 1);
  }

  Variants {
    model: barScreens
    MonitorBar {}
  }
  Variants {
    model: Quickshell.screens
    Dock {}
  }
  Variants {
    model: Quickshell.screens
    RegionOverlay {}
  }
  Variants {
    model: Quickshell.screens
    AnnotateOverlay {}
  }
  WallpaperLayer {}
  Launcher {}
  LockScreen {}
  VolumeOsd {}
  MicOsd {}
  BrightnessOsd {}
  SoftDim {}
  LaptopBlank {}
  NotificationPopups {
    screens: barScreens
  }
  Component.onCompleted: {
    CalendarStore.start();
    FlakeAge.start();
  }
}
