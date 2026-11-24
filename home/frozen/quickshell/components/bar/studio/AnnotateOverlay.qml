import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.components.shared

// Marking up the last screenshot, in the same dimmed full-screen style as the area selector
// (state: Annotator.qml). One window, on the monitor you are working on, made only while editing.
//   tools   PEN, ARROW, BOX, OVAL, MARK (highlighter), TEXT, BLUR (pixelate an area)
//   each tool keeps its own colour, opacity, width (text: font and size), shown in the second row
//   keys    Ctrl+Z undo, Enter done (writes the picture and copies it), Esc cancel
// Everything is drawn in the picture's own pixels (the stage), shown scaled to fit, and the finished
// stage is saved as it is, so nothing is lost to the on-screen size.
Scope {
  id: root

  required property var modelData            // a monitor

  LazyLoader {
    active: Annotator.active && Annotator.screenName === root.modelData.name

    PanelWindow {
      id: win

      // ---- settings (edit here) ----
      readonly property real dimOpacity: 0.65
      readonly property var tools: [
        { id: "pen", name: "PEN" }, { id: "arrow", name: "ARROW" }, { id: "box", name: "BOX" },
        { id: "oval", name: "OVAL" }, { id: "mark", name: "MARK" }, { id: "text", name: "TEXT" },
        { id: "blur", name: "BLUR" }
      ]
      readonly property var colors: [Theme.red, Theme.orange, Theme.yellow, Theme.green, Theme.aqua,
                                     Theme.blue, Theme.purple, "#ffffff", "#000000"]
      readonly property var lineTools: ["pen", "arrow", "box", "oval", "mark"]
      readonly property var lineSizes: [{ name: "S", width: 3 }, { name: "M", width: 6 }, { name: "L", width: 12 }]

      // ---- each tool's own starting settings (widths and sizes are in "1920 px wide" units) ----
      property var opts: ({
        pen:   { color: Theme.red, opacity: 100, width: 6 },
        arrow: { color: Theme.red, opacity: 100, width: 6 },
        box:   { color: Theme.red, opacity: 100, width: 6, fill: false },
        oval:  { color: Theme.red, opacity: 100, width: 6, fill: false },
        mark:  { color: Theme.yellow, opacity: 60, width: 26 },
        text:  { color: Theme.red, opacity: 100, size: 34, font: Theme.fontMono, bold: true, italic: false },
        blur:  { block: 12 }
      })

      // ---- what is being drawn ----
      property string tool: "pen"
      property var shapes: []                   // finished marks, oldest first
      property var draft: null                  // the mark being dragged
      property var editing: null                // { x, y } while a text is being typed
      property string baseFile: StudioState.lastShot     // the picture underneath (the original after REVERT)
      property bool reverted: false
      property bool confirmRevert: false        // REVERT asks twice
      property bool fontsOpen: false

      readonly property var cur: opts[tool]
      // sizes scale with the picture, so a 4K shot is not marked with hairlines
      readonly property real unit: Math.max(1, stage.width / 1920)

      function setOpt(key, value) {
        const next = Object.assign({}, opts[tool]);
        next[key] = value;
        opts = Object.assign({}, opts, { [tool]: next });
      }

      function families() {
        try {
          return [Theme.fontMono, Theme.fontSans].concat(Qt.fontFamilies());
        } catch (e) {
          return [Theme.fontMono, Theme.fontSans];
        }
      }

      screen: root.modelData
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      exclusionMode: ExclusionMode.Ignore
      color: Qt.rgba(0, 0, 0, dimOpacity)

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "qs-annotate"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      onShapesChanged: doneInk.requestPaint()
      onDraftChanged: draftInk.requestPaint()

      // ---- editing ----
      function undo() {
        shapes = shapes.slice(0, -1);
      }

      // back to the untouched capture (Annotator keeps it); DONE then writes that over the edited one
      function revert() {
        commitText();
        draft = null;
        shapes = [];
        baseFile = Annotator.original;
        reverted = true;
        confirmRevert = false;
      }

      function commitText() {
        const t = opts.text;
        if (editing && typing.text.trim() !== "")
          shapes = shapes.concat([{ type: "text", x: editing.x, y: editing.y, text: typing.text, color: t.color,
                                    opacity: t.opacity, size: t.size * unit, font: t.font, bold: t.bold, italic: t.italic }]);
        editing = null;
        typing.text = "";
        keys.forceActiveFocus();
      }

      function cancelText() {
        editing = null;
        typing.text = "";
        keys.forceActiveFocus();
      }

      function finish() {
        commitText();
        if (shapes.length === 0 && !reverted) {
          Annotator.close();
          return;
        }
        stage.grabToImage(result => {
          result.saveToFile(StudioState.lastShot);
          StudioState.shotCount++;           // the preview reloads
          StudioState.copyShot();
          StudioState.shotNote = reverted && shapes.length === 0 ? "REVERTED, COPIED TO THE CLIPBOARD" : "ANNOTATED, COPIED TO THE CLIPBOARD";
          Annotator.close();
        }, Qt.size(stage.width, stage.height));
      }

      // one mark on a canvas (picture pixels)
      function draw(ctx, s) {
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = s.color;
        ctx.fillStyle = s.color;
        ctx.lineWidth = s.w;
        ctx.globalAlpha = s.opacity / 100;
        if (s.type === "pen" || s.type === "mark") {
          if (s.type === "mark")
            ctx.lineCap = "butt";
          ctx.beginPath();
          ctx.moveTo(s.pts[0], s.pts[1]);
          for (let i = 2; i < s.pts.length; i += 2)
            ctx.lineTo(s.pts[i], s.pts[i + 1]);
          if (s.pts.length === 2)
            ctx.lineTo(s.pts[0] + 0.01, s.pts[1]);
          ctx.stroke();
        } else if (s.type === "arrow") {
          const a = Math.atan2(s.y1 - s.y0, s.x1 - s.x0);
          const head = Math.max(s.w * 4, 16 * win.unit);
          ctx.beginPath();
          ctx.moveTo(s.x0, s.y0);
          ctx.lineTo(s.x1 - Math.cos(a) * head * 0.7, s.y1 - Math.sin(a) * head * 0.7);
          ctx.stroke();
          ctx.beginPath();
          ctx.moveTo(s.x1, s.y1);
          ctx.lineTo(s.x1 - head * Math.cos(a - 0.45), s.y1 - head * Math.sin(a - 0.45));
          ctx.lineTo(s.x1 - head * Math.cos(a + 0.45), s.y1 - head * Math.sin(a + 0.45));
          ctx.closePath();
          ctx.fill();
        } else {
          const x = Math.min(s.x0, s.x1), y = Math.min(s.y0, s.y1);
          const w = Math.abs(s.x1 - s.x0), h = Math.abs(s.y1 - s.y0);
          if (s.type === "oval") {
            ctx.beginPath();
            ctx.ellipse(x, y, w, h);
            if (s.fill)
              ctx.fill();
            ctx.stroke();
          } else {
            if (s.fill)
              ctx.fillRect(x, y, w, h);
            ctx.strokeRect(x, y, w, h);            // BOX, and the outline of a BLUR area while dragging
          }
        }
        ctx.globalAlpha = 1;
      }

      // a label, a - and + button and a number you can type: for sizes and percentages
      component NumField: Row {
        id: nf

        property string label: ""
        property int value: 0
        property int min: 1
        property int max: 999
        property int step: 1
        signal edited(int v)
        signal finished                          // Enter was pressed: the caller takes the keyboard back

        spacing: 4
        height: 26

        function apply(n) {
          if (isNaN(n))
            n = value;
          edited(Math.max(min, Math.min(max, Math.round(n))));
          field.text = Qt.binding(() => String(nf.value));       // show the value that was kept
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: nf.label
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        MiniButton { height: 26; padX: 7; text: "-"; onClicked: nf.apply(nf.value - nf.step) }

        Rectangle {
          width: 48
          height: 26
          radius: Retro.corner
          color: Retro.inset
          border.width: Retro.borderWidth
          border.color: field.activeFocus ? Theme.yellow : Theme.fgDim

          TextInput {
            id: field
            anchors.fill: parent
            anchors.margins: 3
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            text: String(nf.value)
            color: Theme.fg
            selectByMouse: true
            inputMethodHints: Qt.ImhDigitsOnly
            font.family: Theme.fontMono
            font.bold: true
            font.pointSize: Theme.fontSize - 1
            onAccepted: {
              nf.apply(parseInt(text));
              nf.finished();
            }
            onActiveFocusChanged: if (!activeFocus) nf.apply(parseInt(text))
          }
        }

        MiniButton { height: 26; padX: 7; text: "+"; onClicked: nf.apply(nf.value + nf.step) }
      }

      // ---- the toolbar: tools and actions, then the settings of the chosen tool ----
      Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: Math.min(win.width - 28, 1060)
        height: barColumn.implicitHeight + 16
        radius: Retro.corner
        color: Theme.bg
        border.width: Retro.borderWidth
        border.color: Theme.fgDim

        Column {
          id: barColumn
          x: 8
          y: 8
          width: parent.width - 16
          spacing: 8

          // the tools on the left; the whole-picture actions in the top right, REVERT last
          Item {
            width: parent.width
            height: 26

            Row {
              spacing: 6

              Repeater {
                model: win.tools

                MiniButton {
                  required property var modelData

                  height: 26
                  text: modelData.name
                  active: win.tool === modelData.id
                  onClicked: {
                    win.commitText();
                    win.fontsOpen = false;
                    win.tool = modelData.id;
                  }
                }
              }
            }

            Row {
              anchors.right: parent.right
              spacing: 6

              MiniButton { height: 26; text: "UNDO"; enabled: win.shapes.length > 0; onClicked: win.undo() }
              MiniButton { height: 26; text: "CLEAR"; enabled: win.shapes.length > 0; onClicked: win.shapes = [] }
              MiniButton { height: 26; text: "DONE"; padX: 14; onClicked: win.finish() }
              MiniButton { height: 26; text: "CANCEL"; danger: true; onClicked: Annotator.close() }
              MiniButton {
                height: 26
                text: win.confirmRevert ? "SURE?" : "REVERT"
                danger: win.confirmRevert
                onClicked: win.confirmRevert ? win.revert() : (win.confirmRevert = true)
              }
            }
          }

          Flow {
            width: parent.width
            spacing: 6

            // colour (every tool but BLUR)
            Repeater {
              model: win.tool === "blur" ? [] : win.colors

              Rectangle {
                required property var modelData

                width: 24
                height: 26
                radius: Retro.corner
                color: modelData
                border.width: Retro.borderWidth
                border.color: Qt.colorEqual(win.cur.color, modelData) ? Theme.fg : Theme.fgDim

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: win.setOpt("color", modelData)
                }
              }
            }

            NumField {
              visible: win.tool !== "blur"
              label: "OPACITY %"
              min: 5
              max: 100
              step: 5
              value: win.cur.opacity !== undefined ? win.cur.opacity : 100
              onEdited: v => win.setOpt("opacity", v)
              onFinished: keys.forceActiveFocus()
            }

            // line tools: width, and quick sizes
            NumField {
              visible: win.lineTools.indexOf(win.tool) !== -1
              label: "WIDTH"
              max: 200
              value: win.cur.width !== undefined ? win.cur.width : 6
              onEdited: v => win.setOpt("width", v)
              onFinished: keys.forceActiveFocus()
            }

            Repeater {
              model: (win.lineTools.indexOf(win.tool) !== -1 && win.tool !== "mark") ? win.lineSizes : []

              MiniButton {
                required property var modelData

                height: 26
                text: modelData.name
                active: win.cur.width === modelData.width
                onClicked: win.setOpt("width", modelData.width)
              }
            }

            MiniButton {
              visible: win.tool === "box" || win.tool === "oval"
              height: 26
              text: "FILL"
              active: !!win.cur.fill
              onClicked: win.setOpt("fill", !win.cur.fill)
            }

            // text: font, size, style
            MiniButton {
              visible: win.tool === "text"
              height: 26
              text: "FONT: " + (win.cur.font || "").toUpperCase()
              active: win.fontsOpen
              onClicked: win.fontsOpen = !win.fontsOpen
            }

            NumField {
              visible: win.tool === "text"
              label: "SIZE"
              min: 6
              max: 600
              value: win.cur.size !== undefined ? win.cur.size : 34
              onEdited: v => win.setOpt("size", v)
              onFinished: keys.forceActiveFocus()
            }

            MiniButton {
              visible: win.tool === "text"
              height: 26
              text: "BOLD"
              active: !!win.cur.bold
              onClicked: win.setOpt("bold", !win.cur.bold)
            }

            MiniButton {
              visible: win.tool === "text"
              height: 26
              text: "ITALIC"
              active: !!win.cur.italic
              onClicked: win.setOpt("italic", !win.cur.italic)
            }

            // blur: how coarse the squares are
            NumField {
              visible: win.tool === "blur"
              label: "SQUARE SIZE"
              min: 2
              max: 200
              value: win.cur.block !== undefined ? win.cur.block : 12
              onEdited: v => win.setOpt("block", v)
              onFinished: keys.forceActiveFocus()
            }
          }
        }
      }

      // REVERT's "SURE?" goes back to REVERT if you do not press it again
      Timer {
        interval: 3000
        running: win.confirmRevert
        onTriggered: win.confirmRevert = false
      }

      // ---- the picture, shown to fit ----
      Item {
        id: holder

        // the room left under the toolbar
        readonly property real room: win.height - (bar.y + bar.height) - 30
        readonly property real fit: Math.min(1, (win.width - 40) / Math.max(1, stage.width), room / Math.max(1, stage.height))

        width: stage.width * fit
        height: stage.height * fit
        x: (win.width - width) / 2
        y: bar.y + bar.height + 14 + Math.max(0, (room - height) / 2)

        Rectangle {
          anchors.fill: parent
          anchors.margins: -Retro.borderWidth
          color: "transparent"
          border.width: Retro.borderWidth
          border.color: Theme.fgDim
        }

        Item {
          width: stage.width
          height: stage.height
          scale: holder.fit
          transformOrigin: Item.TopLeft

          // the stage: what is saved. Picture first, then the marks over it.
          Item {
            id: stage
            width: base.implicitWidth
            height: base.implicitHeight

            Image {
              id: base
              cache: false
              asynchronous: false
              source: win.baseFile !== "" ? "file://" + win.baseFile : ""
            }

            // BLUR areas: the picture under them, drawn small and enlarged without smoothing
            Repeater {
              model: win.shapes.filter(s => s.type === "blur")

              ShaderEffectSource {
                required property var modelData

                readonly property real bx: Math.min(modelData.x0, modelData.x1)
                readonly property real by: Math.min(modelData.y0, modelData.y1)
                readonly property real bw: Math.max(1, Math.abs(modelData.x1 - modelData.x0))
                readonly property real bh: Math.max(1, Math.abs(modelData.y1 - modelData.y0))
                readonly property real square: Math.max(1, modelData.block * win.unit)

                sourceItem: base
                sourceRect: Qt.rect(bx, by, bw, bh)
                textureSize: Qt.size(Math.max(1, Math.round(bw / square)), Math.max(1, Math.round(bh / square)))
                smooth: false
                x: bx
                y: by
                width: bw
                height: bh
              }
            }

            Canvas {
              id: doneInk
              anchors.fill: parent
              renderTarget: Canvas.FramebufferObject
              onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                for (const s of win.shapes) {
                  if (s.type !== "blur" && s.type !== "text")
                    win.draw(ctx, s);
                }
              }
            }

            Repeater {
              model: win.shapes.filter(s => s.type === "text")

              Text {
                required property var modelData

                x: modelData.x
                y: modelData.y
                text: modelData.text
                color: modelData.color
                opacity: modelData.opacity / 100
                font.family: modelData.font
                font.bold: modelData.bold
                font.italic: modelData.italic
                font.pixelSize: modelData.size
              }
            }

            // the text being typed (part of the stage, so it is the size it will be)
            TextInput {
              id: typing
              visible: win.editing !== null
              x: win.editing ? win.editing.x : 0
              y: win.editing ? win.editing.y : 0
              color: win.opts.text.color
              opacity: win.opts.text.opacity / 100
              font.family: win.opts.text.font
              font.bold: win.opts.text.bold
              font.italic: win.opts.text.italic
              font.pixelSize: win.opts.text.size * win.unit
              onVisibleChanged: if (visible) forceActiveFocus()
              onAccepted: win.commitText()
              Keys.onEscapePressed: win.cancelText()
            }

            // the mark being dragged is kept off the finished canvas, so only it repaints while drawing
            Canvas {
              id: draftInk
              anchors.fill: parent
              renderTarget: Canvas.FramebufferObject
              onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (win.draft)
                  win.draw(ctx, win.draft);
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.CrossCursor

          onPressed: mouse => {
            const x = mouse.x / holder.fit, y = mouse.y / holder.fit;
            win.fontsOpen = false;
            win.commitText();
            if (win.tool === "text") {
              win.editing = { x: x, y: y };
              return;
            }
            const o = win.cur;
            const blur = win.tool === "blur";
            const mark = {
              type: win.tool,
              color: blur ? "#ffffff" : o.color,
              opacity: blur ? 100 : o.opacity,
              w: blur ? 2 * win.unit : o.width * win.unit,
              fill: !!o.fill,
              block: o.block
            };
            win.draft = (win.tool === "pen" || win.tool === "mark")
              ? Object.assign(mark, { pts: [x, y] })
              : Object.assign(mark, { x0: x, y0: y, x1: x, y1: y });
          }

          onPositionChanged: mouse => {
            if (!pressed || !win.draft)
              return;
            const x = mouse.x / holder.fit, y = mouse.y / holder.fit;
            const d = Object.assign({}, win.draft);
            if (d.pts) {
              d.pts = d.pts.concat([x, y]);
            } else {
              d.x1 = x;
              d.y1 = y;
            }
            win.draft = d;
          }

          onReleased: {
            const d = win.draft;
            win.draft = null;
            if (!d)
              return;
            const tiny = d.pts ? false : Math.abs(d.x1 - d.x0) < 3 && Math.abs(d.y1 - d.y0) < 3;
            if (!tiny)
              win.shapes = win.shapes.concat([d]);
          }
        }
      }

      // ---- the font list (TEXT tool) ----
      Rectangle {
        visible: win.fontsOpen && win.tool === "text"
        z: 10
        x: Math.max(14, Math.min(win.width - width - 14, bar.x + 8))
        y: bar.y + bar.height + 4
        width: 340
        height: 280
        radius: Retro.corner
        color: Theme.bg
        border.width: Retro.borderWidth
        border.color: Theme.fgDim

        ListView {
          anchors.fill: parent
          anchors.margins: 6
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: win.fontsOpen ? win.families() : []

          delegate: Rectangle {
            required property string modelData

            width: ListView.view.width
            height: 26
            color: hover.containsMouse ? Theme.bgSel : "transparent"

            Text {
              anchors.verticalCenter: parent.verticalCenter
              x: 6
              width: parent.width - 12
              elide: Text.ElideRight
              text: modelData
              color: modelData === win.cur.font ? Theme.orange : Theme.fg
              font.family: modelData
              font.pointSize: Theme.fontSize
            }

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                win.setOpt("font", modelData);
                win.fontsOpen = false;
              }
            }
          }
        }
      }

      // ---- the keyboard ----
      Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            if (win.fontsOpen)
              win.fontsOpen = false;
            else
              Annotator.close();
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            win.finish();
          } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            win.undo();
          } else {
            return;
          }
          event.accepted = true;
        }
      }
    }
  }
}
