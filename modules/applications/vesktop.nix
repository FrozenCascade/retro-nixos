{ pkgs, ... }:

# Discord client. Installed from nixpkgs and not Flatpak, because Flatpak apps cannot be started outside the VPN
# (see modules/system/vpn-bypass.nix). Its name, icon and VPN setting are in settings.nix (apps."vesktop").
{
  environment.systemPackages = [ pkgs.vesktop ];
}
