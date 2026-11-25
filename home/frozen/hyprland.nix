{ config, lib, pkgs, ... }:
let
  settings = import ./settings-load.nix { inherit lib; };
  toLua = import ./lib/lua.nix { inherit lib; };

  c = config.lib.stylix.colors;
  names = [
    "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07"
    "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F"
  ];
  entries = lib.concatMapStringsSep "\n" (n: "  ${n} = \"${c.${n}}\",") names;
  themeLua = ''
    -- Generated from the Stylix palette (edit colors in the theme, not here)
    local theme = {
    ${entries}
    }

  '';

  # Monitors and workspace count, shared with Quickshell (see settings.nix)
  settingsLua = ''
    -- Generated from home/frozen/settings.nix
    local settings = {
      external_monitor = "${settings.externalMonitor}",
      laptop_monitor   = "${settings.laptopMonitor}",
      laptop_workspace = "${settings.laptopWorkspace}",
      workspace_count  = ${toString settings.workspaceCount},
      kb_layout        = "${lib.concatMapStringsSep "," (l: l.code) settings.keyboardLayouts}",
      kb_variant       = "${lib.concatMapStringsSep "," (l: l.variant) settings.keyboardLayouts}",
    }

  '';

  # Tools the Lua config starts, as exact store paths
  toolsLua = ''
    -- Generated from Nix: tool paths
    local tools = {
      cliphist = "${pkgs.cliphist}/bin/cliphist",
      wl_paste = "${pkgs.wl-clipboard}/bin/wl-paste",
    }

  '';

  # Plugin library paths from Nix
  pluginsLua = ''
    -- Generated from Nix: plugin library paths
    local plugin_paths = {
      dynamic_cursors = "${pkgs.hyprlandPlugins.hypr-dynamic-cursors}/lib/libhypr-dynamic-cursors.so",
    }

  '';

  # Window rules for applications, from apps/entries.nix
  appRules = import ./apps/window-rules.nix { inherit lib; } (import ./apps/entries.nix);
  appsLua = ''
    -- Generated from home/frozen/apps/entries.nix: window rules for applications
    local app_rules = ${toLua appRules}

  '';

  # The Lua files in ./hypr, joined in this order into one hyprland.lua (they share one scope).
  # core must stay first; plugins stays last on purpose. To add a file, put it in ./hypr and list it here.
  luaFiles = [
    "core"
    "monitors"
    "look"
    "input"
    "binds"
    "hardware-keys"
    "mouse"
    "studio"
    "workspaces"
    "hidden"
    "shortcuts"
    "rules/general"
    "rules/shell"
    "rules/apps"
    "animations"
    "autostart"
    "plugins"
  ];
  body = lib.concatMapStringsSep "\n" (name: builtins.readFile ./hypr/${name}.lua) luaFiles;
in
{
  xdg.configFile."hypr/hyprland.lua".text =
    themeLua + settingsLua + toolsLua + pluginsLua + appsLua + body;
}
