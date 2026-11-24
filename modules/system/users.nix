{ config, pkgs, ... }:

{
  users.users."frozen" = {
    isNormalUser = true;
    description = "Frozen";
    extraGroups = [ "networkmanager" "wheel" ];
  };
}
