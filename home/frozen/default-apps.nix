{ lib, ... }:

# Which program opens what. The file manager is set in settings.nix (defaultApps.fileManager).
let
  settings = import ./settings-load.nix { inherit lib; };
  files = settings.defaultApps.fileManager;     # set in settings.nix (defaultApps)
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
