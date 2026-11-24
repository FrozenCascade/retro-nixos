import QtQuick
import qs

// RAIN: falling streaks over the wallpaper picture and under whatever mode is on (WallpaperLayer.qml).
// It is switched per monitor on the Display window's WALLPAPER tab; colour, speed, density, slant and frame
// rate are shared by both monitors (WallpaperState).
// Cost: no shader and no big texture, just a few hundred small rectangles that one timer moves. The window
// is redrawn `rainFps` times a second, so lowering the frame rate is the main way to make it lighter, and it
// stands still while the screen is locked.
Item {
  id: root

  property string monitorName: ""

  readonly property var cfg: WallpaperState.cfg(monitorName)

  // ---- edit here ----
  readonly property real baseCount: 90           // drops on a 1920x1080 screen at density 0 ...
  readonly property real extraCount: 260         // ... plus this many more at density 1 (bigger screens get more)
  readonly property int maxCount: 600
  readonly property real minLength: 0.014        // streak length as a part of the screen height: far drops ...
  readonly property real maxLength: 0.045        // ... to near drops
  readonly property real slowFall: 0.55          // near drops fall this many screens per second at speed 0 ...
  readonly property real fastFall: 1.9           // ... and this many at speed 1
  readonly property real farShare: 0.55          // the farthest drops fall at this part of the near drops' speed
  readonly property real maxSlant: 30            // degrees of lean at either end of the slant slider

  readonly property color tint: WallpaperState.accentColor(cfg.rainColor)
  readonly property real slant: (cfg.rainSlant - 0.5) * 2 * maxSlant          // degrees; positive leans to the right
  readonly property real drift: Math.tan(slant * Math.PI / 180)             // sideways pixels per pixel fallen
  readonly property real fall: height * (slowFall + cfg.rainSpeed * (fastFall - slowFall))      // pixels per second, near drops
  readonly property int count: Math.min(maxCount, Math.round((baseCount + cfg.rainDensity * extraCount) * width * height / (1920 * 1080)))

  Repeater {
    id: drops
    model: root.count

    Rectangle {
      id: drop

      // 0 = far, 1 = near; chosen once for this drop (a binding with nothing to watch runs once)
      readonly property real depth: Math.random()
      readonly property real len: root.height * (root.minLength + depth * (root.maxLength - root.minLength))

      width: depth > 0.5 ? 2 : 1
      height: len
      radius: width / 2
      antialiasing: true
      color: root.tint
      opacity: 0.12 + depth * 0.38
      rotation: -root.slant
      x: Math.random() * root.width
      y: Math.random() * root.height - len          // spread out at the start, not all at the top

      function step(dt) {
        const speed = root.fall * (root.farShare + (1 - root.farShare) * depth);
        y += speed * dt;
        x += speed * root.drift * dt;
        if (y > root.height) {
          // back to the top; with a slant the start is spread wider so the far side is not left dry
          const lean = root.height * Math.abs(root.drift);
          y = -len;
          x = Math.random() * (root.width + lean) - (root.drift > 0 ? lean : 0);
        }
      }
    }
  }

  Timer {
    id: clock

    property real last: 0

    interval: Math.round(1000 / root.cfg.rainFps)
    repeat: true
    running: root.visible && !LockState.locked
    onRunningChanged: last = 0
    onTriggered: {
      const now = Date.now();
      const dt = last === 0 ? interval / 1000 : Math.min(0.1, (now - last) / 1000);     // the real time passed, so the speed does not depend on the frame rate
      last = now;
      for (let i = 0; i < drops.count; i++)
        drops.itemAt(i).step(dt);
    }
  }
}
