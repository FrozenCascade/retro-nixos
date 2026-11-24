{ pkgs, ... }:

{
  programs.thunar = {
    enable = true;

    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  # Preserve Thunar preferences outside an Xfce session.
  programs.xfconf.enable = true;

  # Mounting, Trash, remote locations, and thumbnails.
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.udisks2.enable = true;

  environment.systemPackages = with pkgs; [
    file-roller
    catfish
  ];
}
