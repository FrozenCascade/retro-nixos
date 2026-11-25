# Merges settings.defaults.nix with your settings.nix and checks the result, so a typo stops the
# build with a readable message instead of reaching Hyprland or Quickshell.
# Use it anywhere settings are needed:   settings = import ./settings-load.nix { inherit lib; };
{ lib }:
let
  merged = lib.recursiveUpdate (import ./settings.defaults.nix) (import ./settings.nix);
in
assert lib.assertMsg
  (merged.workspaceCount >= 1 && merged.workspaceCount <= 10)
  "settings.nix: workspaceCount must be between 1 and 10";
assert lib.assertMsg
  (merged.keyboardLayouts != [ ])
  "settings.nix: keyboardLayouts needs at least one layout";
assert lib.assertMsg
  (merged.power.lockMinutes >= 1 && merged.power.lockMinutes < merged.power.suspendMinutes)
  "settings.nix: power.lockMinutes must be at least 1 and smaller than power.suspendMinutes";
assert lib.assertMsg
  (merged.bar.height > merged.bar.revealHeight)
  "settings.nix: bar.height must be larger than bar.revealHeight";
merged
