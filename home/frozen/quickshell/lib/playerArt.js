.pragma library

// The picture to show for a music or video player.
// YouTube pages: the video's own thumbnail, worked out from the page address the browser reports
// (xesam:url), because browsers often hand over no artwork or only the site icon.
// Anything else: the artwork the player reports (trackArtUrl).
function urlFor(player) {
  if (!player)
    return "";

  const meta = player.metadata || {};
  const page = String(meta["xesam:url"] || "");
  const m = page.match(/(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|shorts\/|embed\/|live\/)|youtu\.be\/)([\w-]{11})/);

  if (m)
    return "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg";      // 16:9 with no black bars

  return player.trackArtUrl || "";
}
