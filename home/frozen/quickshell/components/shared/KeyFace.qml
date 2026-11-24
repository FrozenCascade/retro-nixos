import QtQuick
import qs

// The raised key look the bar buttons share: a hard shadow under a face.
//   down   pressed in: no shadow, selected color (a window it opens is showing)
//   lit    selected color only, for hover
// Size it with anchors.fill: parent, or give it a width and height.
Item {
  id: key

  property bool down: false
  property bool lit: false

  Rectangle {
    x: 2
    y: 2
    width: key.width
    height: key.height
    radius: Retro.corner
    color: Retro.shadowColor
    visible: !key.down
  }

  Rectangle {
    anchors.fill: parent
    radius: Retro.corner
    color: key.down || key.lit ? Theme.bgSel : Theme.bgAlt
  }
}
