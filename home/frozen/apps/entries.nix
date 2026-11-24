# Applications: menu entries, default apps and window rules, all declared here.
# This is the in-code version of KDE's Menu Editor (entries) and Window Rules (window).
#
# Each attribute name is the app's id: the name of its .desktop file, without ".desktop".
# Every field is optional. Leave out what you do not need.
#
#   MENU ENTRY (what the launcher shows)
#     name, genericName, comment   the texts shown in the launcher
#     exec, icon                   the command, and an icon name or path
#     terminal                     run it inside a terminal
#     categories                   menu categories, e.g. [ "Network" "WebBrowser" ]
#     mimeType                     file types the app says it can open
#     startupNotify                the cursor busy animation while it starts
#     hide = true                  keep the app out of the menu (the entry stays installed)
#
#   DEFAULT APP
#     defaultFor                   file types this app opens by default, e.g. [ "text/html" ]
#
#   WINDOW RULE (what Hyprland does with its window)
#     window.match                 how to find the window; see class and title in `hyprctl clients`
#     window.set                   what to do with it: float, size, move, workspace, pin, opacity, ...
#
# To change an app that a package already installs, use its desktop file name as the id and list only
# the fields you want to change. Your entry replaces the package's one.
#
# Entries and defaults are applied by home/frozen/apps/default.nix, rules by hypr/rules/apps.lua.
# Rules apply in alphabetical order of the id; keep the matches distinct so the order never matters.
{
  # A new entry that also opens as a floating window:
  #
  # "btop" = {
  #   name = "Btop";
  #   comment = "Resource monitor";
  #   exec = "kitty --title btop btop";
  #   icon = "utilities-system-monitor";
  #   categories = [ "System" "Monitor" ];
  #   window = {
  #     match = { title = "^btop$"; };
  #     set = { float = true; size = [ "900" "600" ]; };
  #   };
  # };

  # Hide a package's entry from the menu:
  #
  # "org.kde.kate".hide = true;

  # Make a browser the default for web links (use the desktop file name of the one you installed):
  #
  # "firefox".defaultFor = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];

  # Send an app's window to a workspace without touching its menu entry:
  #
  # "mpv".window = {
  #   match = { class = "^mpv$"; };
  #   set = { workspace = "3"; };
  # };
}
