import Quickshell
import QtQuick

Image {
  id: icon

  property string name: ""
  property string category: "apps"
  property string fallback: "application-x-executable"

  readonly property string clean: String(name || "").replace(/-symbolic$/, "")

  asynchronous: true
  fillMode: Image.PreserveAspectFit

  sourceSize: Qt.size(
    Math.max(width, 1) * 2,
                      Math.max(height, 1) * 2
  )

  source: Quickshell.iconPath(
    clean !== "" ? clean : fallback,
    fallback
  )
}
