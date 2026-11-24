{ pkgs, ... }:

# Web browsers. Vivaldi is unfree software, so the system needs nixpkgs.config.allowUnfree = true
# (or an allow list that names "vivaldi") somewhere in the host config.
{
  home.packages = [
    (pkgs.vivaldi.override {
      enableWidevine = true;                             # protected streaming
      commandLineArgs = "--ozone-platform-hint=auto";    # a native Wayland window, not XWayland
    })
  ];
}
