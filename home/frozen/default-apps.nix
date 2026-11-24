{ lib, ... }:

# Which program opens what. Dolphin is the file manager; change the one name below to switch.
let
  files = "org.kde.dolphin.desktop";
in
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = lib.mkForce [ files ];
      "application/x-directory" = lib.mkForce [ files ];
    };
    # "Open With" lists Dolphin first
    associations.added."inode/directory" = [ files ];
  };
}
