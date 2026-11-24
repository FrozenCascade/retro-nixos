# Applies entries.nix: desktop entries (the launcher menu) and default applications.
# The window rules from the same file are picked up by hyprland.nix.
{ lib, ... }:
let
  apps = import ./entries.nix;

  # Fields copied straight into the .desktop file. Same names as Home Manager's xdg.desktopEntries.
  entryFields = [
    "name"
    "genericName"
    "comment"
    "exec"
    "icon"
    "terminal"
    "categories"
    "mimeType"
    "startupNotify"
  ];

  # An app gets a .desktop file when it sets at least one of them, or hides itself
  hasEntry = app: app.hide or false || lib.any (field: app ? ${field}) entryFields;

  toEntry =
    id: app:
    # name is required by the format, so it falls back to the id
    { name = id; }
    // lib.getAttrs (lib.filter (field: app ? ${field}) entryFields) app
    // lib.optionalAttrs (app.hide or false) { noDisplay = true; };

  # "text/html" -> "firefox.desktop", gathered from every app's defaultFor
  defaults = lib.foldlAttrs (
    found: id: app:
    found // lib.genAttrs (app.defaultFor or [ ]) (_: "${id}.desktop")
  ) { } apps;
in
{
  xdg.desktopEntries = lib.mapAttrs toEntry (lib.filterAttrs (_: hasEntry) apps);

  # Only touches ~/.config/mimeapps.list when an app asks for a default. If a hand-made one already
  # exists, move it aside once so Home Manager can take the file over.
  xdg.mimeApps = lib.mkIf (defaults != { }) {
    enable = true;
    defaultApplications = defaults;
  };
}
