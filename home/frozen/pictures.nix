{ lib, config, ... }:

# The folders under ~/Pictures that other parts of the config write to or read from.
#   Wallpapers   what the wallpaper picker lists (WallpaperState.pictureDirs)
#   Screenshots  where the Studio window saves captures
{
  home.activation.pictureFolders = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.home.homeDirectory}/Pictures/Wallpapers" "${config.home.homeDirectory}/Pictures/Screenshots"
  '';
}
