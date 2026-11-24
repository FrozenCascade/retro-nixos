import QtQuick
import qs
import qs.components.shared
import qs.components.bar.calendar

// Downloads with yt-dlp: paste a link, pick what you want, press DOWNLOAD.
// The options are StudioDownloader's; the same link can come from  qs ipc call studio download <link>
Flickable {
  id: tab

  contentWidth: width
  contentHeight: col.implicitHeight + 10
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick

  readonly property bool video: StudioDownloader.mode === "video"

  Connections {
    target: StudioDownloader

    function onPasted(text) {
      link.text = text;
    }
  }

  // a row of choices where one is active; `choices` are the values, `label` turns one into text
  component Choice: Flow {
    id: choice

    property var choices: []
    property var current
    property var label: v => String(v).toUpperCase()
    signal picked(var value)

    width: col.width
    spacing: 6

    Repeater {
      model: choice.choices

      MiniButton {
        required property var modelData

        text: choice.label(modelData)
        active: choice.current === modelData
        onClicked: choice.picked(modelData)
      }
    }
  }

  Column {
    id: col
    width: tab.width
    spacing: 12

    // ---- the link ----
    Row {
      width: parent.width
      spacing: 8

      FieldBox {
        id: link
        width: parent.width - paste.width - 8
        height: 28
        placeholder: "PASTE A LINK (SEVERAL: SEPARATE WITH SPACES)"
        onAccepted: StudioDownloader.start(text)
        onEscaped: text = ""
      }

      MiniButton {
        id: paste
        height: 28
        text: "PASTE"
        onClicked: StudioDownloader.paste()
      }
    }

    Row {
      spacing: 14
      height: 30

      MiniButton {
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        padX: 26
        danger: StudioDownloader.busy
        text: StudioDownloader.busy ? "STOP" : "DOWNLOAD"
        onClicked: StudioDownloader.busy ? StudioDownloader.stop() : StudioDownloader.start(link.text)
      }

      MiniButton {
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        text: "OPEN FOLDER"
        onClicked: StudioDownloader.openFolder()
      }
    }

    // progress
    Column {
      width: parent.width
      spacing: 4
      visible: StudioDownloader.busy

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: StudioDownloader.title !== "" ? StudioDownloader.title.toUpperCase() : "STARTING..."
        color: Theme.fg
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Rectangle {
        width: parent.width
        height: 12
        radius: Retro.corner
        color: Retro.inset
        border.width: Retro.borderWidth
        border.color: Theme.fgDim

        Rectangle {
          x: 2
          y: 2
          height: parent.height - 4
          width: Math.max(0, (parent.width - 4) * Math.max(0, StudioDownloader.percent) / 100)
          color: Theme.orange
        }
      }

      Text {
        text: (StudioDownloader.percent >= 0 ? StudioDownloader.percent.toFixed(1) + "%" : "")
              + (StudioDownloader.speedText !== "" ? "   " + StudioDownloader.speedText : "")
              + (StudioDownloader.etaText !== "" ? "   ETA " + StudioDownloader.etaText : "")
        color: Theme.orange
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 2
      }
    }

    Text {
      width: parent.width
      visible: text !== "" && !StudioDownloader.busy
      wrapMode: Text.WordWrap
      text: StudioDownloader.note
      color: StudioDownloader.note.indexOf("FAILED") === 0 ? Theme.red : Theme.green
      font.family: Theme.fontMono
      font.bold: true
      font.pointSize: Theme.fontSize - 2
    }

    // ---- what ----
    SectionHead { width: parent.width; text: "WHAT" }

    Choice {
      choices: ["video", "audio"]
      current: StudioDownloader.mode
      label: v => v === "video" ? "VIDEO" : "AUDIO ONLY"
      onPicked: v => StudioDownloader.set("mode", v)
    }

    Column {
      width: parent.width
      spacing: 8
      visible: tab.video

      Text {
        text: "BEST QUALITY UP TO"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Choice {
        choices: StudioDownloader.heightChoices
        current: StudioDownloader.maxHeight
        label: v => StudioDownloader.heightName(v)
        onPicked: v => StudioDownloader.set("maxHeight", v)
      }

      Text {
        text: "FILE TYPE"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Choice {
        choices: StudioDownloader.containerChoices
        current: StudioDownloader.container
        onPicked: v => StudioDownloader.set("container", v)
      }
    }

    Column {
      width: parent.width
      spacing: 8
      visible: !tab.video

      Text {
        text: "AUDIO FORMAT"
        color: Theme.fgDim
        font.family: Theme.fontMono
        font.bold: true
        font.pointSize: Theme.fontSize - 1
      }

      Choice {
        choices: StudioDownloader.audioChoices
        current: StudioDownloader.audioFormat
        onPicked: v => StudioDownloader.set("audioFormat", v)
      }
    }

    // ---- extras ----
    SectionHead { width: parent.width; text: "EXTRAS" }

    CheckRow {
      label: "WHOLE PLAYLIST (IF THE LINK IS IN ONE)"
      checked: StudioDownloader.playlist
      onToggled: StudioDownloader.set("playlist", !StudioDownloader.playlist)
    }

    CheckRow {
      visible: tab.video
      label: "SUBTITLES (ENGLISH, INSIDE THE FILE)"
      checked: StudioDownloader.subtitles
      onToggled: StudioDownloader.set("subtitles", !StudioDownloader.subtitles)
    }

    CheckRow {
      label: "COVER PICTURE INSIDE THE FILE"
      checked: StudioDownloader.thumbnail
      onToggled: StudioDownloader.set("thumbnail", !StudioDownloader.thumbnail)
    }

    CheckRow {
      label: "TITLE AND TAGS INSIDE THE FILE"
      checked: StudioDownloader.metadata
      onToggled: StudioDownloader.set("metadata", !StudioDownloader.metadata)
    }

    CheckRow {
      label: "CUT SPONSOR PARTS (SPONSORBLOCK)"
      checked: StudioDownloader.sponsorblock
      onToggled: StudioDownloader.set("sponsorblock", !StudioDownloader.sponsorblock)
    }

    // ---- limits ----
    SectionHead { width: parent.width; text: "SPEED LIMIT" }

    Choice {
      choices: StudioDownloader.speedChoices
      current: StudioDownloader.speed
      label: v => v === 0 ? "NONE" : v + " MB/S"
      onPicked: v => StudioDownloader.set("speed", v)
    }

    SectionHead { width: parent.width; text: "LOGIN COOKIES FROM" }

    Choice {
      choices: StudioDownloader.browserChoices
      current: StudioDownloader.cookies
      label: v => v === "" ? "NONE" : v.toUpperCase()
      onPicked: v => StudioDownloader.set("cookies", v)
    }

    // ---- recent ----
    SectionHead { width: parent.width; visible: StudioDownloader.history.length > 0; text: "RECENT" }

    Repeater {
      model: StudioDownloader.history

      Text {
        required property var modelData

        width: col.width
        elide: Text.ElideRight
        text: (modelData.ok ? "OK  " : "FAILED  ") + modelData.title.toUpperCase()
        color: modelData.ok ? Theme.fg : Theme.red
        font.family: Theme.fontMono
        font.pointSize: Theme.fontSize - 2
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "VIDEOS GO TO ~/VIDEOS/DOWNLOADS, AUDIO TO ~/MUSIC/DOWNLOADS."
      color: Theme.fgDim
      font.family: Theme.fontMono
      font.pointSize: Theme.fontSize - 2
    }
  }
}
