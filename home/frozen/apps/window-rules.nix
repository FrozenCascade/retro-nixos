# Picks the apps in entries.nix that have a `window` block and returns them as a list of
# { name, match, set }. hyprland.nix turns that list into the app_rules table that
# hypr/rules/apps.lua loops over.
{ lib }:
apps:
lib.mapAttrsToList (id: app: {
  name = "app-${id}";
  match = app.window.match;
  set = app.window.set or { };
}) (lib.filterAttrs (_: app: app ? window) apps)
