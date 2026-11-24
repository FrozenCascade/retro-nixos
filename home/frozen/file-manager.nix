{ lib, ... }:

# Dolphin is the program that opens folders. Anything asking for "a file manager" (Vivaldi's
# "show in folder", Discord, portals) goes through the inode/directory type below.
{
  xdg.mimeApps.defaultApplications."inode/directory" = lib.mkForce [ "org.kde.dolphin.desktop" ];
}
