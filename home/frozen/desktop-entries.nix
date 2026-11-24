{ ... }:

# Full launcher entries written from scratch, for apps that need a custom command or ship no entry of their own.
# To only change an app's name, icon, comment or categories, use the `apps` table in settings.nix instead.
# The file in ~/.local/share/applications wins over the package's own, so launchers (fuzzel, the Quickshell
# launcher) show these. Never define the same id here and in `apps`: the two would fight over one file.
{
  # kitty as a plain "Terminal". To make another entry like it, copy this block and use the app's desktop file id.
  xdg.desktopEntries.kitty = {
    name = "Terminal";
    genericName = "Terminal Emulator";
    comment = "Open a command line";
    exec = "kitty";
    icon = "utilities-terminal";
    categories = [ "System" "TerminalEmulator" ];
    settings.StartupWMClass = "kitty";   # keeps the bar and overview matching windows to this entry
  };
}
