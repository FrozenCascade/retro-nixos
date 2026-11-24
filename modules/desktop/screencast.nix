{ pkgs, ... }:

# Screen recording and sharing (Discord, OBS, browsers).
# Apps ask the portal for a screen, the Hyprland portal shows the picker and hands them a PipeWire stream.
# If sharing breaks, check in order:  systemctl --user status xdg-desktop-portal-hyprland
#                                     journalctl --user -u xdg-desktop-portal -b | tail -30
{
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];

    # edit here: which backend answers which request (first one that works wins)
    config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  # Electron apps (Vesktop) otherwise run through XWayland, where the screen picker cannot see Wayland screens
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
