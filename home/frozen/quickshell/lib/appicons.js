.pragma library

// How the bar's title box shows an app: the app's own symbolic icon when the icon theme has one, otherwise
// a one colour glyph chosen here (icon themes like Gruvbox Plus have no symbolic icons at all).
// Glyphs come from the Nerd Font (Font Awesome range); change one by pasting another code point.
// Lookup order: byApp, then byCategory, then `fallback`.

// by window class or desktop file id, lowercase (hyprctl activewindow shows the class)
const glyphByApp = {
  "kitty": "",              // terminal
  "org.kde.dolphin": "",    // folder
  "firefox": "",
  "spotify": "",
  "steam": "",
  "discord": ""
};

// icons forced by window class, lowercase: wins over the desktop entry's own icon
const iconByApp = {
  "kitty": "utilities-terminal"
};

// by the Categories line of the app's .desktop file, most specific first
const glyphByCategory = [
  ["TerminalEmulator", ""],
  ["FileManager", ""],
  ["WebBrowser", ""],
  ["TextEditor", ""],
  ["Calculator", ""],
  ["IDE", ""],
  ["Video", ""],
  ["Player", ""],
  ["Audio", ""],
  ["AudioVideo", ""],
  ["Graphics", ""],
  ["Game", ""],
  ["Office", ""],
  ["Development", ""],
  ["Network", ""],
  ["Settings", ""],
  ["System", ""],
  ["Utility", ""]
];

const glyphFallback = "";   // a cube

// Names shown instead of the desktop file's own (by window class, lowercase).
const names = {
  "kitty": "Terminal"
};

function glyph(appId, categories) {
  const id = String(appId || "").toLowerCase();
  if (glyphByApp[id])
    return glyphByApp[id];
  const cats = Array.from(categories || []);
  for (const pair of glyphByCategory)
    if (cats.indexOf(pair[0]) !== -1)
      return pair[1];
  return glyphFallback;
}
