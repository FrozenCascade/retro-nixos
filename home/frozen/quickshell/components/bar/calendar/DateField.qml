import QtQuick
import qs
import "../../../lib/calendar.js" as Cal

// A date you can type as YYYY-MM-DD. Anything that is not a date puts the old one back.
Row {
  id: field

  property int dn: 0

  signal edited(int dn)

  spacing: 6

  onDnChanged: {
    if (!box.focused)
      box.text = Cal.keyOf(dn);
  }
  Component.onCompleted: box.text = Cal.keyOf(dn)

  FieldBox {
    id: box
    width: 112
    height: 26
    onCommitted: {
      const v = Cal.dnOfKey(text.trim());
      if (!isNaN(v) && v >= Cal.MIN_DN && v <= Cal.MAX_DN)
        field.edited(v);
      text = Cal.keyOf(field.dn);
    }
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    text: Cal.DAYS_SHORT[Cal.weekday(field.dn)]
    color: Theme.fgDim
    font.family: Theme.fontMono
    font.bold: true
    font.pointSize: Theme.fontSize - 2
  }
}
