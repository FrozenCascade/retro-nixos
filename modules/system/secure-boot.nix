{ inputs, lib, pkgs, ... }:

# Secure Boot with Lanzaboote: it signs the boot files on every rebuild, so each new generation boots with
# Secure Boot on. Off until you turn `enable` on, because it needs your own keys first.
#
# Setup, in this order (the quick start: https://nix-community.github.io/lanzaboote/):
#   1. rebuild once with enable = false (this installs the sbctl tool)
#   2. sudo sbctl create-keys
#   3. set enable = true below, rebuild, then check:  sudo sbctl verify
#   4. reboot into the firmware (HP: F10), set Secure Boot to Setup Mode (clear its keys), save and boot NixOS
#   5. sudo sbctl enroll-keys --microsoft     (keeps the Microsoft keys, which some firmware drivers expect)
#   6. reboot, turn Secure Boot on in the firmware, then check:  bootctl status   ("Secure Boot: enabled (user)")
# Keep a NixOS installer USB until it works: with Secure Boot on and something unsigned, the laptop will not boot.
# To go back: turn Secure Boot off in the firmware, set enable = false, rebuild.
let
  enable = true;       # edit here
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [ pkgs.sbctl ];

  # Lanzaboote takes over from systemd-boot
  boot.loader.systemd-boot.enable = lib.mkIf enable (lib.mkForce false);

  boot.lanzaboote = {
    inherit enable;
    pkiBundle = "/var/lib/sbctl";
    configurationLimit = 5;       # generations kept in the boot menu
  };
}
