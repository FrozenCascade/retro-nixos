pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// A picture for a YouTube tab whose browser reports none. Vivaldi and Firefox often send only the page
// title ("Song - YouTube") and no artwork or address, so the title is looked up on YouTube (yt-dlp),
// and the video's thumbnail is built from the id it finds. Results are remembered while the shell runs.
// The first search result is used, so an unusual title can occasionally give a different video.
Singleton {
  id: root

  readonly property string suffix: "YouTube"
  property string art: ""                   // the thumbnail for what is playing now, "" when unknown
  property var known: ({})                  // search text -> thumbnail address
  property int tries: 0                     // searches made for the current title (the network may not be up yet)
  readonly property int maxTries: 4

  // the player that is playing, else the first one (same rule as the music displays)
  readonly property var player: {
    const all = Mpris.players.values;
    return all.find(p => p.isPlaying) || all[0] || null;
  }

  // "(3) Song - YouTube" -> "Song"; "" when the title is not a YouTube tab or the player has its own artwork
  readonly property string query: {
    if (!player || player.trackArtUrl)
      return "";
    const m = String(player.trackTitle || "").match(/^(?:\(\d+\)\s*)?(.*?)\s+-\s+YouTube(?: Music)?$/);
    return m ? m[1].trim() : "";
  }

  onQueryChanged: {
    if (query === "") {
      art = "";
    } else if (known[query]) {
      art = known[query];
    } else {
      art = "";
      tries = 0;
      settle.interval = 800;
      settle.restart();
    }
  }

  // wait a moment so a title that is still changing is not searched for
  Timer {
    id: settle
    interval: 800
    onTriggered: {
      if (root.query !== "" && !search.running) {
        search.asked = root.query;
        search.command = [Tools.ytDlp, "--no-warnings", "--skip-download", "--playlist-items", "1", "--print", "id", "ytsearch1:" + root.query];
        search.running = true;
      }
    }
  }

  Process {
    id: search

    property string asked: ""

    stdout: StdioCollector {
      onStreamFinished: {
        const id = text.trim().split("\n")[0];
        if (!/^[\w-]{11}$/.test(id)) {
          // no answer (probably no network yet right after login): try again a little later
          if (root.query === search.asked && ++root.tries < root.maxTries) {
            settle.interval = 5000;
            settle.restart();
          }
          return;
        }
        const url = "https://i.ytimg.com/vi/" + id + "/mqdefault.jpg";        // 16:9, no black bars
        root.known = Object.assign({}, root.known, { [search.asked]: url });
        if (root.query === search.asked)
          root.art = url;
      }
    }
  }
}
