import QtQuick
import qs
import qs.components.bar.quick
import qs.components.bar.system
import qs.components.bar.weather

// The left end of the bar: pin, system, weather and quick buttons, each followed by a separator.
// It only wires buttons to the two controllers; what each button looks like is in its own file.
// To add a button here: put it in its feature folder, then add it and a BarSep below.
Row {
  id: root

  required property var popups          // PopupController
  required property var autoHide        // AutoHide

  // the bar anchors the popups under these two
  property alias statusButton: status
  property alias weatherButton: weather

  spacing: 6

  PinButton {
    pinned: root.autoHide.pinned
    onToggled: root.autoHide.togglePinned()
    onHideRequested: root.autoHide.forceHide()
  }
  BarSep {}

  StatusButton {
    id: status
    open: root.popups.isOpen("status")
    onClicked: root.popups.toggle("status")
  }
  BarSep {}

  WeatherButton {
    id: weather
    open: root.popups.isOpen("weather")
    onClicked: root.popups.toggle("weather")
    // middle click hides the weather everywhere (or shows it again)
    onMiddleClicked: {
      Weather.toggleHidden();
      root.popups.close("weather");
    }
  }
  BarSep {}

  QuickButton {
    open: root.popups.isOpen("quick")
    onClicked: root.popups.toggle("quick")
    // middle click switches the keyboard layout, like Super+'
    onMiddleClicked: KeyboardState.next()
  }
  BarSep {}
}
