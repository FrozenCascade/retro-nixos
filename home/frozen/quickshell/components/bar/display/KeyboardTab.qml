import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.components.shared
import qs.components.bar.tools
import qs.components.bar.calendar

// The KEYBOARD tab: backlight of the NuPhy Air96 V2 (brightness, colour, effect, speed), over the cable.
// The work is done by lib/nuphy-via.py. Values are applied right away and held in the keyboard's memory
// until it is unplugged; SAVE ON KEYBOARD keeps them.
Flickable {
  id: flick

  // ---- edit here ----
  readonly property string script: Quickshell.shellPath("lib/nuphy-via.py")
  readonly property int rgbChannel: 3                          // VIA channel of the RGB matrix
  readonly property int effectCount: 45                        // how far the effect buttons go (the keyboard ignores the rest)
  // colour presets: name, hue (0-255), saturation (0-255). Hue 0-255 is the colour wheel: 85 green, 170 blue
  readonly property var colors: [
    { name: "WHITE", hue: 0, sat: 0 },
    { name: "RED", hue: 0, sat: 255 },
    { name: "ORANGE", hue: 21, sat: 255 },
    { name: "YELLOW", hue: 42, sat: 255 },
    { name: "GREEN", hue: 85, sat: 255 },
    { name: "AQUA", hue: 128, sat: 255 },
    { name: "BLUE", hue: 170, sat: 255 },
    { name: "PURPLE", hue: 198, sat: 255 },
    { name: "PINK", hue: 233, sat: 255 }
  ]

  property bool found: false
  property string error: ""
  property var values: ({ brightness: 0, effect: 0, speed: 0, hue: 0, sat: 0 })

  clip: true
  contentWidth: width
  contentHeight: col.implicitHeight + 8
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  onVisibleChanged: {
    if (visible)
      refresh();
  }

  function refresh() {
    if (!getProc.running)
      getProc.running = true;
  }

  // ---- sending: changes wait a moment and go out one at a time ----
  property var queue: ({})                                     // value id -> bytes

  function send(valueId, bytes) {
    queue = Object.assign({}, queue, { [valueId]: bytes });
    flushTimer.restart();
  }

  function set(patch) {
    values = Object.assign({}, values, patch);
  }

  Timer {
    id: flushTimer
    interval: 120
    onTriggered: flick.flush()
  }

  function flush() {
    if (setProc.running)
      return;
    const ids = Object.keys(queue);
    if (ids.length === 0)
      return;
    const id = ids[0];
    const bytes = queue[id];
    const rest = Object.assign({}, queue);
    delete rest[id];
    queue = rest;
    setProc.command = [Tools.python, script, "set", String(rgbChannel), id].concat(bytes.map(String));
    setProc.running = true;
  }

  Process {
    id: getProc
    command: [Tools.python, flick.script, "get"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text);
          flick.found = d.connected === true && d.rgb !== undefined;
          flick.error = d.error || "";
          if (flick.found)
            flick.values = d.rgb;
        } catch (e) {
          flick.found = false;
          flick.error = "NO ANSWER";
        }
      }
    }
  }

  Process {
    id: setProc
    onExited: flick.flush()
  }

  Process {
    id: saveProc
    command: [Tools.python, flick.script, "save", String(flick.rgbChannel)]
  }

  // ---- the tab ----
  Column {
    id: col
    width: flick.width
    spacing: 8

    Row {
      spacing: 8

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: flick.found ? "NUPHY AIR96 V2 CONNECTED" : (flick.error !== "" ? flick.error : "LOOKING FOR THE KEYBOARD")
        color: flick.found ? Theme.green : Theme.red
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      MiniButton {
        text: "RETRY"
        onClicked: flick.refresh()
      }
    }

    SectionHead { visible: flick.found; width: parent.width; text: "BACKLIGHT" }

    Repeater {
      model: [
        { label: "BRIGHTNESS", key: "brightness", id: 1 },
        { label: "SPEED", key: "speed", id: 3 }
      ]

      Item {
        required property var modelData

        visible: flick.found
        width: col.width
        height: visible ? 24 : 0

        Text {
          width: 96
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        LineSlider {
          x: 100
          width: parent.width - 100
          anchors.verticalCenter: parent.verticalCenter
          value: flick.values[parent.modelData.key] / 255
          step: 0.05
          fill: Theme.orange
          onMoved: v => {
            const b = Math.round(v * 255);
            flick.set({ [parent.modelData.key]: b });
            flick.send(parent.modelData.id, [b]);
          }
        }
      }
    }

    SectionHead { visible: flick.found; width: parent.width; text: "COLOUR" }

    Flow {
      visible: flick.found
      width: parent.width
      spacing: 6

      Repeater {
        model: flick.colors

        MiniButton {
          required property var modelData

          text: modelData.name
          active: flick.values.hue === modelData.hue && flick.values.sat === modelData.sat
          onClicked: {
            flick.set({ hue: modelData.hue, sat: modelData.sat });
            flick.send(4, [modelData.hue, modelData.sat]);
          }
        }
      }
    }

    Repeater {
      model: [
        { label: "HUE", key: "hue" },
        { label: "SATURATION", key: "sat" }
      ]

      Item {
        required property var modelData

        visible: flick.found
        width: col.width
        height: visible ? 24 : 0

        Text {
          width: 96
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.label
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        LineSlider {
          x: 100
          width: parent.width - 100
          anchors.verticalCenter: parent.verticalCenter
          value: flick.values[parent.modelData.key] / 255
          step: 0.02
          fill: Theme.orange
          onMoved: v => {
            flick.set({ [parent.modelData.key]: Math.round(v * 255) });
            flick.send(4, [flick.values.hue, flick.values.sat]);
          }
        }
      }
    }

    SectionHead { visible: flick.found; width: parent.width; text: "EFFECT" }

    Row {
      visible: flick.found
      spacing: 8

      MiniButton {
        text: "<"
        onClicked: {
          const e = Math.max(0, flick.values.effect - 1);
          flick.set({ effect: e });
          flick.send(2, [e]);
        }
      }

      Text {
        width: 110
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: flick.values.effect === 0 ? "OFF" : "EFFECT " + flick.values.effect
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize
      }

      MiniButton {
        text: ">"
        onClicked: {
          const e = Math.min(flick.effectCount, flick.values.effect + 1);
          flick.set({ effect: e });
          flick.send(2, [e]);
        }
      }
    }

    MiniButton {
      visible: flick.found
      text: "SAVE ON KEYBOARD"
      onClicked: saveProc.running = true
    }

    Text {
      visible: flick.found
      width: parent.width
      wrapMode: Text.WordWrap
      text: "WORKS ON THE CABLE ONLY. EFFECT 0 TURNS THE BACKLIGHT OFF. THE SIDE LIGHT IS NOT HERE YET."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }
}
