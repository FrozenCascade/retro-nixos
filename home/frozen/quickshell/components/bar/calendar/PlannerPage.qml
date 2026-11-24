import QtQuick
import qs
import qs.components.shared
import "../../../lib/calendar.js" as Cal

// The second tab: add reminders and events, switch things on and off, pick holiday sources and the time zone.
// Editing something from the calendar reuses the form at the top (renamed EDIT) and hides everything else.
Item {
  id: page

  property bool active: false
  property int selectedDn: 0

  property string editId: ""
  property string kind: "reminder"
  property int startDn: 0
  property int endDn: 0                // events: the last day
  property int hour: 9
  property int minute: 0
  property int length: 0               // reminders: minutes from the start to the end
  property bool allDay: false
  property bool notify: true
  property string note: ""

  readonly property bool editing: editId !== ""
  readonly property int endAbs: startDn * 1440 + hour * 60 + minute + length
  readonly property int rEndDn: Math.floor(endAbs / 1440)
  readonly property int rEndMin: endAbs - rEndDn * 1440

  signal leaveField
  signal finishedEdit(int dn)

  // moving the start carries the end with it (same length, same span)
  function setStart(dn) {
    endDn += dn - startDn;
    startDn = dn;
  }

  // typing an end date or time sets the length
  function setEnd(dn, min) {
    length = Math.max(0, dn * 1440 + min - (startDn * 1440 + hour * 60 + minute));
  }

  function fresh() {
    editId = "";
    titleField.text = "";
    startDn = selectedDn;
    endDn = selectedDn;
    hour = (Clock.zd.getUTCHours() + 1) % 24;
    minute = 0;
    length = 0;
    allDay = false;
    notify = true;
    note = "";
    flick.contentY = 0;
  }

  function reset() {
    kind = "reminder";
    fresh();
  }

  function newItem() {
    fresh();
    focusTitle();
  }

  function focusTitle() {
    flick.contentY = 0;
    titleField.focusIt();
  }

  function startEdit(k, id) {
    const it = CalendarStore.item(k, id);
    if (!it)
      return;
    kind = k;
    editId = id;
    note = "";
    titleField.text = it.title;
    startDn = it.dn;
    if (k === "reminder") {
      hour = Math.floor(it.minute / 60);
      minute = it.minute % 60;
      length = it.length;
      notify = it.notify;
      endDn = it.dn;
    } else {
      endDn = it.dnEnd;
      allDay = it.time === "";
      hour = allDay ? 9 : +it.time.slice(0, 2);
      minute = allDay ? 0 : +it.time.slice(3, 5);
    }
    flick.contentY = 0;
  }

  function cancelEdit() {
    editId = "";
    titleField.text = "";
    finishedEdit(selectedDn);
  }

  function submit() {
    const title = titleField.text.trim();
    if (title === "") {
      note = "TYPE A TITLE FIRST";
      noteTimer.restart();
      return;
    }
    const time = allDay ? "" : Cal.pad2(hour) + ":" + Cal.pad2(minute);
    if (kind === "reminder")
      CalendarStore.addReminder(title, startDn, hour * 60 + minute, length, notify, editId);
    else if (editing)
      CalendarStore.updateEvent(editId, title, startDn, Math.max(startDn, endDn), time);
    else
      CalendarStore.addEvent(title, startDn, Math.max(startDn, endDn), time);

    const shown = startDn;
    titleField.text = "";
    if (editing) {
      editId = "";
      finishedEdit(shown);
    } else {
      note = (kind === "reminder" ? "REMINDER" : "EVENT") + " ADDED FOR " + Cal.keyOf(shown);
      noteTimer.restart();
    }
  }

  onActiveChanged: {
    if (active) {
      Clock.loadZones();
      if (!editing) {
        startDn = selectedDn;
        endDn = Math.max(endDn, selectedDn);
        if (endDn < startDn || kind === "reminder")
          endDn = startDn;
      }
    } else if (editing) {
      editId = "";
      titleField.text = "";
    }
  }

  Timer { id: noteTimer; interval: 2500; onTriggered: page.note = "" }

  Flickable {
    id: flick
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 10
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: flick.width
      spacing: 10

      SectionHead { width: parent.width; text: page.editing ? "EDIT" : "NEW" }

      Row {
        id: kinds
        width: parent.width
        spacing: 8
        visible: !page.editing
        RetroTab { width: (kinds.width - 8) / 2; label: "REMINDER"; selected: page.kind === "reminder"; onClicked: page.kind = "reminder" }
        RetroTab { width: (kinds.width - 8) / 2; label: "EVENT"; selected: page.kind === "event"; onClicked: page.kind = "event" }
      }

      FieldBox {
        id: titleField
        width: parent.width
        placeholder: page.kind === "reminder" ? "WHAT TO REMIND YOU OF" : "WHAT IS HAPPENING"
        onAccepted: page.submit()
        onEscaped: page.leaveField()
      }

      // start: a date to type, and the time
      Row {
        spacing: 8
        height: 26
        Text { anchors.verticalCenter: parent.verticalCenter; width: 52; text: "START"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
        DateField { anchors.verticalCenter: parent.verticalCenter; dn: page.startDn; onEdited: d => page.setStart(d) }
        NumberField { anchors.verticalCenter: parent.verticalCenter; value: page.hour; from: 0; to: 23; wrap: true; onEdited: v => page.hour = v }
        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize }
        NumberField { anchors.verticalCenter: parent.verticalCenter; value: page.minute; from: 0; to: 59; wrap: true; onEdited: v => page.minute = v }
      }

      // reminders: end date and time (changing them changes the length)
      Row {
        visible: page.kind === "reminder"
        spacing: 8
        height: 26
        Text { anchors.verticalCenter: parent.verticalCenter; width: 52; text: "END"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
        DateField { anchors.verticalCenter: parent.verticalCenter; dn: page.rEndDn; onEdited: d => page.setEnd(d, page.rEndMin) }
        NumberField { anchors.verticalCenter: parent.verticalCenter; value: Math.floor(page.rEndMin / 60); from: 0; to: 23; onEdited: v => page.setEnd(page.rEndDn, v * 60 + page.rEndMin % 60) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize }
        NumberField { anchors.verticalCenter: parent.verticalCenter; value: page.rEndMin % 60; from: 0; to: 59; onEdited: v => page.setEnd(page.rEndDn, Math.floor(page.rEndMin / 60) * 60 + v) }
      }

      Row {
        visible: page.kind === "reminder"
        spacing: 8
        height: 26
        Text { anchors.verticalCenter: parent.verticalCenter; width: 52; text: "LENGTH"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
        FieldBox {
          id: lenField
          width: 112
          height: 26
          placeholder: "1h 30m"
          onCommitted: {
            const v = Cal.parseLength(text);
            if (!isNaN(v))
              page.length = Math.min(525600, v);
            text = Cal.lengthText(page.length);
          }
          onEscaped: page.leaveField()
        }
        MiniButton { anchors.verticalCenter: parent.verticalCenter; text: "-5"; onClicked: page.length = Math.max(0, page.length - 5) }
        MiniButton { anchors.verticalCenter: parent.verticalCenter; text: "+5"; onClicked: page.length += 5 }
        MiniButton { anchors.verticalCenter: parent.verticalCenter; text: "+1H"; onClicked: page.length += 60 }
      }

      // events: a last day to type, and an all-day switch
      Row {
        visible: page.kind === "event"
        spacing: 8
        height: 26
        Text { anchors.verticalCenter: parent.verticalCenter; width: 52; text: "END"; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
        DateField { anchors.verticalCenter: parent.verticalCenter; dn: Math.max(page.endDn, page.startDn); onEdited: d => page.endDn = Math.max(page.startDn, d) }
      }

      CheckRow { visible: page.kind === "event"; label: "ALL DAY (IGNORES THE TIME)"; checked: page.allDay; onToggled: v => page.allDay = v }
      CheckRow { visible: page.kind === "reminder"; label: "SEND A NOTIFICATION WHEN IT STARTS"; checked: page.notify; onToggled: v => page.notify = v }

      Row {
        spacing: 8
        height: 30
        MiniButton { width: 150; height: 28; text: page.editing ? "SAVE" : (page.kind === "reminder" ? "ADD REMINDER" : "ADD EVENT"); onClicked: page.submit() }
        MiniButton { visible: page.editing; width: 100; height: 28; text: "CANCEL"; onClicked: page.cancelEdit() }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: 180
          elide: Text.ElideRight
          text: page.note
          color: Theme.orange
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }
      }

      // everything below hides while editing
      Column {
        id: more
        width: parent.width
        spacing: 10
        visible: !page.editing

        SectionHead { width: parent.width; text: "SHOW" }
        CheckRow { label: "REMINDERS"; checked: CalendarStore.settings.showReminders; onToggled: v => CalendarStore.setSetting("showReminders", v) }
        CheckRow { label: "EVENTS"; checked: CalendarStore.settings.showEvents; onToggled: v => CalendarStore.setSetting("showEvents", v) }
        CheckRow { label: "HOLIDAYS"; checked: CalendarStore.settings.showHolidays; onToggled: v => CalendarStore.setSetting("showHolidays", v) }
        CheckRow { label: "MOON PHASES"; checked: CalendarStore.settings.showMoon; onToggled: v => CalendarStore.setSetting("showMoon", v) }
        CheckRow { label: "SEASONS (EQUINOXES AND SOLSTICES)"; checked: CalendarStore.settings.showSeasons; onToggled: v => CalendarStore.setSetting("showSeasons", v) }
        CheckRow { label: "WEEK STARTS ON MONDAY"; checked: CalendarStore.settings.weekStartsMonday; onToggled: v => CalendarStore.setSetting("weekStartsMonday", v) }

        SectionHead { width: parent.width; text: "HOLIDAY SOURCES" }
        CheckRow { label: "US FEDERAL HOLIDAYS"; checked: CalendarStore.settings.srcUsFederal; onToggled: v => CalendarStore.setSetting("srcUsFederal", v) }
        CheckRow { label: "US OBSERVANCES (EASTER, DST, MOTHER'S DAY...)"; checked: CalendarStore.settings.srcUsObservances; onToggled: v => CalendarStore.setSetting("srcUsObservances", v) }

        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: CalendarStore.settings.countries
            delegate: Row {
              required property string modelData
              spacing: 4
              Text { anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.fg; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 1 }
              MiniButton { text: "x"; danger: true; onClicked: CalendarStore.removeCountry(modelData) }
            }
          }
        }

        Row {
          spacing: 6
          FieldBox { id: countryField; width: 270; height: 26; placeholder: "COUNTRY CODE (DE, JP, GB...)"; onAccepted: { CalendarStore.addCountry(text); text = ""; } onEscaped: page.leaveField() }
          MiniButton { height: 26; text: "ADD"; onClicked: { CalendarStore.addCountry(countryField.text); countryField.text = ""; } }
          MiniButton { height: 26; text: "REFRESH"; onClicked: CalendarStore.refreshHolidays(Clock.zd.getUTCFullYear()) }
        }

        Text {
          visible: CalendarStore.fetchNote !== ""
          text: CalendarStore.fetchNote
          color: Theme.fgDim
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 2
        }

        SectionHead { width: parent.width; text: "TIME ZONE" }

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: Clock.zoneName + "   " + Clock.offsetLabel + (Clock.zone === "" ? "   (FOLLOWING SYSTEM)" : "")
          color: Theme.fg
          font.family: Theme.fontMono
          font.bold: true
          font.pointSize: Theme.fontSize - 1
        }

        Row {
          spacing: 6
          MiniButton { height: 26; text: "AUTO-DETECT"; onClicked: Clock.detect() }
          MiniButton { height: 26; text: "FOLLOW SYSTEM"; onClicked: Clock.setZone("") }
          Text { anchors.verticalCenter: parent.verticalCenter; text: Clock.detectNote; color: Theme.fgDim; font.family: Theme.fontMono; font.bold: true; font.pointSize: Theme.fontSize - 2 }
        }

        FieldBox { id: zoneField; width: parent.width; height: 26; placeholder: "FIND A ZONE (TOKYO, CHICAGO...)"; onEscaped: page.leaveField() }

        Column {
          width: parent.width
          spacing: 4
          Repeater {
            model: Clock.findZones(zoneField.text, 6)
            delegate: MiniButton {
              required property string modelData
              width: col.width
              text: modelData
              onClicked: {
                Clock.choose(modelData);
                zoneField.text = "";
              }
            }
          }
        }

        CheckRow { label: "ALSO CHANGE THE SYSTEM TIME ZONE (ASKS FOR PASSWORD)"; checked: CalendarStore.settings.alsoSystemZone; onToggled: v => CalendarStore.setSetting("alsoSystemZone", v) }
      }
    }
  }

  // keep the typed length in step with the number
  Connections {
    target: page
    function onLengthChanged() {
      if (!lenField.focused)
        lenField.text = Cal.lengthText(page.length);
    }
  }

  Component.onCompleted: lenField.text = Cal.lengthText(length)
}
