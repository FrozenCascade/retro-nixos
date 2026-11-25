# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop/desktopbase.nix
    ../../modules/desktop/kde-apps.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/screencast.nix
    ../../modules/system/secure-boot.nix
    ../../modules/system/hardware.nix
    ../../modules/system/vpn-bypass.nix
    ../../modules/system/studio.nix
    ../../modules/system/fingerprint.nix
    ../../modules/system/bluetooth.nix
    ../../modules/system/privacy.nix
    ../../modules/system/power.nix
    ../../modules/system/btrfs.nix
    ../../modules/desktop/color-picker.nix
    ../../modules/desktop/sddm-sleep.nix
    ../../modules/desktop/terminal.nix
    ../../modules/desktop/storage.nix
    ../../modules/desktop/lock.nix
    ../../modules/desktop/sddm.nix
    ../../modules/system/shell-services.nix
    ../../modules/system/users.nix
    ../../modules/system/swap.nix
    ../../modules/system/theme.nix
    ../../modules/system/fonts.nix
    ../../modules/applications/thunar.nix
    ../../modules/applications/vesktop.nix
    ../../modules/applications/media.nix
    ../../modules/applications/creative.nix
    ../../modules/applications/kde-games.nix
    ../../modules/applications/gprojector.nix
    ../../modules/applications/lution.nix
    ../../modules/applications/partition-manager.nix
    ../../modules/applications/steam.nix
    ../../modules/applications/flatpak.nix
    ../../modules/applications/virtualisation.nix
    ../../modules/applications/input-remapper.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Core applications
  programs.firefox.enable = true;

  # Enable git
  programs.git.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

    # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    users.frozen = import ../../home/frozen;
  };

  # System state version
  system.stateVersion = "26.05";
}
