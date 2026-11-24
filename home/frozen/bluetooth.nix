{ lib, ... }:

# Bluetooth Manager (blueman) with an icon from the icon theme. The stock launcher entry names an icon the
# Gruvbox-Plus theme does not have, so it showed a blank placeholder in the launcher and dock.
# The entry's text is only a default (mkDefault); the icon is forced.
{
  xdg.desktopEntries.blueman-manager = {
    name = lib.mkDefault "Bluetooth Manager";
    genericName = lib.mkDefault "Bluetooth";
    comment = lib.mkDefault "Pair and manage Bluetooth devices";
    exec = lib.mkDefault "blueman-manager";
    icon = lib.mkForce "blueman-device";             # any icon name in the theme works here
    categories = lib.mkDefault [ "Settings" "HardwareSettings" ];
    startupNotify = lib.mkDefault true;
  };
}
