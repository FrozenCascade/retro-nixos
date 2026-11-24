import QtQuick
import qs

// MATRIX: falling characters on a dark background. Colour, speed and density are set per monitor in the
// Display window. It only paints while it is the active mode (the layer unloads it otherwise).
Item {
  id: root

  property string monitorName: ""

  readonly property var cfg: WallpaperState.cfg(monitorName)
  readonly property color tint: WallpaperState.accentColor(cfg.matrixColor)

  // ---- edit here ----
  readonly property int cell: 16                       // size of one character, in pixels
  readonly property real trailFade: 0.14               // higher = shorter trails
  readonly property string alphabet: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789"

  // speed 0..1 -> one step every 110 ms (slow) down to 35 ms (fast)
  readonly property int stepMs: Math.round(110 - cfg.matrixSpeed * 75)

  property var drops: []                               // per column: the row of the head, or -1 while waiting

  // a new colour or density starts the rain over, so the change shows at once
  onTintChanged: drops = []
  readonly property real density: cfg.matrixDensity
  onDensityChanged: drops = []

  function glyph() {
    return alphabet.charAt(Math.floor(Math.random() * alphabet.length));
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.bg
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderTarget: Canvas.FramebufferObject

    onPaint: {
      const ctx = getContext("2d");
      const cols = Math.floor(width / root.cell);
      if (root.drops.length !== cols) {
        root.drops = Array.from({ length: cols }, () => -1);
        ctx.fillStyle = Theme.bg;
        ctx.fillRect(0, 0, width, height);
      }

      // fade what is already there, so each head leaves a trail
      ctx.fillStyle = Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.trailFade);
      ctx.fillRect(0, 0, width, height);
      ctx.font = root.cell + "px '" + Theme.fontMono + "'";
      ctx.textBaseline = "top";

      const lead = Qt.lighter(root.tint, 1.7);
      const rows = Math.ceil(height / root.cell);
      const spawn = root.density * 0.06;

      for (let c = 0; c < cols; c++) {
        const row = root.drops[c];
        if (row < 0) {
          if (Math.random() < spawn)
            root.drops[c] = 0;
          continue;
        }
        const x = c * root.cell;
        ctx.fillStyle = root.tint;                       // the previous head turns into the trail colour
        ctx.fillText(root.glyph(), x, (row - 1) * root.cell);
        ctx.fillStyle = lead;
        ctx.fillText(root.glyph(), x, row * root.cell);
        root.drops[c] = row > rows && Math.random() > 0.94 ? -1 : row + 1;
      }
    }
  }

  Timer {
    interval: root.stepMs
    repeat: true
    running: true
    onTriggered: canvas.requestPaint()
  }
}
