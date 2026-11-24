import QtQuick
import qs

// SNAKE: a small game on the wallpaper. Click the board to start; arrows or WASD steer, R restarts,
// Escape stops the game. The keyboard goes to the wallpaper only after you click it (on-demand focus), keys
// are ignored while no game is on, and the game clock runs only while playing.
Item {
  id: root

  property string monitorName: ""

  // ---- edit here ----
  readonly property int cols: 32
  readonly property int rows: 18
  readonly property int tickMs: 115

  property string phase: "idle"          // idle, playing or over
  property var snake: []
  property var food: ({ x: 0, y: 0 })
  property var heading: ({ x: 1, y: 0 })
  property var queued: ({ x: 1, y: 0 })  // the turn to take on the next tick
  property int score: 0
  property int best: 0

  readonly property real cellSize: Math.max(12, Math.min(28, Math.floor(Math.min(width * 0.8 / cols, height * 0.7 / rows))))

  function start() {
    snake = [{ x: 8, y: 9 }, { x: 7, y: 9 }, { x: 6, y: 9 }];
    heading = { x: 1, y: 0 };
    queued = heading;
    score = 0;
    placeFood();
    phase = "playing";
    board.requestPaint();
  }

  function stop() {
    phase = "idle";
    board.requestPaint();
  }

  function placeFood() {
    for (let tries = 0; tries < 200; tries++) {
      const f = { x: Math.floor(Math.random() * cols), y: Math.floor(Math.random() * rows) };
      if (!snake.some(s => s.x === f.x && s.y === f.y)) {
        food = f;
        return;
      }
    }
  }

  function tick() {
    heading = queued;
    const head = { x: snake[0].x + heading.x, y: snake[0].y + heading.y };
    const eats = head.x === food.x && head.y === food.y;
    const body = eats ? snake : snake.slice(0, -1);       // the tail moves away unless we grow
    if (head.x < 0 || head.y < 0 || head.x >= cols || head.y >= rows || body.some(s => s.x === head.x && s.y === head.y)) {
      phase = "over";
      best = Math.max(best, score);
      board.requestPaint();
      return;
    }
    snake = [head].concat(body);
    if (eats) {
      score++;
      placeFood();
    }
    board.requestPaint();
  }

  // a turn that would reverse into the body is ignored
  function steer(dx, dy) {
    if (dx === -heading.x && dy === -heading.y)
      return;
    queued = { x: dx, y: dy };
  }

  focus: true
  Keys.onPressed: event => {
    const k = event.key;
    if (k === Qt.Key_Escape) {
      stop();
    } else if (k === Qt.Key_R) {
      start();
    } else if (phase === "playing") {
      if (k === Qt.Key_Up || k === Qt.Key_W)
        steer(0, -1);
      else if (k === Qt.Key_Down || k === Qt.Key_S)
        steer(0, 1);
      else if (k === Qt.Key_Left || k === Qt.Key_A)
        steer(-1, 0);
      else if (k === Qt.Key_Right || k === Qt.Key_D)
        steer(1, 0);
      else
        return;
    } else {
      return;
    }
    event.accepted = true;
  }

  Timer {
    interval: root.tickMs
    repeat: true
    running: root.phase === "playing"
    onTriggered: root.tick()
  }

  // ---- the board ----
  Item {
    id: frame
    anchors.centerIn: parent
    width: root.cols * root.cellSize
    height: root.rows * root.cellSize

    Rectangle {
      x: Retro.shadowOffset
      y: Retro.shadowOffset
      width: parent.width
      height: parent.height
      radius: Retro.corner
      color: Retro.shadowColor
    }

    Rectangle {
      anchors.fill: parent
      radius: Retro.corner
      color: Theme.bg
      border.width: Retro.borderWidth
      border.color: Theme.fg
    }

    Canvas {
      id: board
      anchors.fill: parent
      anchors.margins: Retro.borderWidth
      renderTarget: Canvas.FramebufferObject

      onPaint: {
        const ctx = getContext("2d");
        const s = root.cellSize;
        ctx.clearRect(0, 0, width, height);
        // faint grid
        ctx.strokeStyle = Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.18);
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let x = 1; x < root.cols; x++) {
          ctx.moveTo(x * s, 0);
          ctx.lineTo(x * s, root.rows * s);
        }
        for (let y = 1; y < root.rows; y++) {
          ctx.moveTo(0, y * s);
          ctx.lineTo(root.cols * s, y * s);
        }
        ctx.stroke();
        if (root.phase === "idle")
          return;
        ctx.fillStyle = Theme.red;
        ctx.fillRect(root.food.x * s + 3, root.food.y * s + 3, s - 6, s - 6);
        root.snake.forEach((p, i) => {
          ctx.fillStyle = i === 0 ? Theme.yellow : Theme.orange;
          ctx.fillRect(p.x * s + 1, p.y * s + 1, s - 2, s - 2);
        });
      }
    }

    // score above the board
    Text {
      anchors { left: parent.left; bottom: parent.top; bottomMargin: 8 }
      text: "SNAKE   SCORE " + root.score + "   BEST " + root.best
      color: Theme.fg
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize + 1
    }

    // what to do next
    Text {
      anchors { right: parent.right; bottom: parent.top; bottomMargin: 8 }
      text: root.phase === "idle" ? "CLICK THE BOARD TO PLAY" : (root.phase === "over" ? "GAME OVER   R RESTART   ESC EXIT" : "ARROWS OR WASD   R RESTART   ESC EXIT")
      color: root.phase === "over" ? Theme.red : Theme.fgDim
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 1
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        root.forceActiveFocus();
        if (root.phase !== "playing")
          root.start();
      }
    }
  }
}
