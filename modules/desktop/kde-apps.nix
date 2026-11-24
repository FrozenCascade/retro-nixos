{ pkgs, ... }:
{
  # KDE applications without enabling the Plasma desktop
  environment.systemPackages = with pkgs.kdePackages; [
    gwenview
    dolphin
    ark
    okular
    kate
    kio-extras
    kdegraphics-thumbnailers
    ffmpegthumbs
    kimageformats
    breeze-icons
    breeze
    plasma-integration
    kde-cli-tools
    kservice
    kconfig
    kleopatra
  ];

    # GnuPG agent with a graphical passphrase dialog
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
  };

  xdg.portal.config.hyprland = {
    default = [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.FileChoo ser" = [ "kde" ];
  };

  # KDE portal backend, including Dolphin's application chooser
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
  };

  # Application-menu metadata used by KDE application discovery
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # Match Hyprland's XDG_MENU_PREFIX=hyprland-
  environment.etc."xdg/menus/hyprland-applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  services.power-profiles-daemon.enable = true;
  programs.dconf.enable = true;
  security.polkit.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        (action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount" ||
         action.id == "org.freedesktop.udisks2.encrypted-unlock-system" ||
         action.id == "org.freedesktop.udisks2.encrypted-unlock") &&
        subject.isInGroup("wheel")
      ) {
        return polkit.Result.YES;
      }
    });
  '';
}
