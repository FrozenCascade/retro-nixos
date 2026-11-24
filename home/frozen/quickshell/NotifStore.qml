pragma Singleton
import Quickshell
import QtQuick

// A history of notifications (NotificationPopups feeds it), the silent switch, and "repop": showing an
// old entry again on the popup stack without sending a new notification.
Singleton {
  id: root

  property var items: []        // newest first: { id, app, appIcon, image, summary, body, time, urgency }
  property int unread: 0
  property bool silent: false   // silent: no popups (urgent ones still show); the list still fills
  property var temp: []         // entries brought back on screen right now (stand-ins for Notification objects)
  property int tempSeq: 0

  // the same entries grouped by app, newest group first
  readonly property var groups: {
    const map = {};
    const order = [];
    for (const e of items) {
      const k = e.app || "NOTIFICATION";
      if (!map[k]) {
        map[k] = { app: k, icon: e.appIcon, items: [] };
        order.push(k);
      }
      map[k].items.push(e);
    }
    return order.map(k => map[k]);
  }

  function record(n) {
    const clean = s => String(s || "").replace(/<[^>]*>/g, "").trim();
    const entry = { id: Date.now() + Math.random(), app: clean(n.appName), appIcon: n.appIcon || "", image: n.image || "", summary: clean(n.summary), body: clean(n.body), time: Date.now(), urgency: n.urgency };
    items = [entry].concat(items).slice(0, 80);
    unread++;
  }

  function remove(id) {
    items = items.filter(x => x.id !== id);
  }

  function clearApp(app) {
    items = items.filter(x => (x.app || "NOTIFICATION") !== app);
  }

  function clear() {
    items = [];
    unread = 0;
  }

  function markRead() {
    unread = 0;
  }

  // The popup card only needs these fields and dismiss()/expire(), so a plain object can stand in.
  function repop(e) {
    const id = ++tempSeq;
    const shim = {
      id: id, urgency: e.urgency, actions: [], image: e.image, appIcon: e.appIcon,
      appName: e.app, summary: e.summary, body: e.body,
      dismiss: () => root.dropTemp(id), expire: () => root.dropTemp(id)
    };
    temp = temp.concat([shim]);
  }

  // show a message on the popup stack right now, ignoring the silent switch (for TEST buttons)
  function preview(app, icon, summary, body) {
    repop({ urgency: 1, image: "", appIcon: icon || "", app: app, summary: summary, body: body || "" });
    Sounds.play("notify");
  }

  function dropTemp(id) {
    temp = temp.filter(t => t.id !== id);
  }

  function copy(e) {
    const text = (e.app ? e.app + ": " : "") + e.summary + (e.body ? "\n" + e.body : "");
    Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | "$2"', "sh", text, Tools.wlCopy]);
  }

  function iconFor(name) {
    if (!name)
      return Quickshell.iconPath("dialog-information");
    if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:"))
      return name;
    return Quickshell.iconPath(name, "dialog-information");
  }

  function ago(ms) {
    const m = Math.floor((Clock.nowMs - ms) / 60000);
    if (m < 1)
      return "NOW";
    if (m < 60)
      return m + " MIN AGO";
    if (m < 1440)
      return Math.floor(m / 60) + " H AGO";
    return Math.floor(m / 1440) + " D AGO";
  }
}
