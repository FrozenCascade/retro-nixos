{ pkgs, ... }:

# Steam and the usual helpers for running games. Games and their Proton prefixes live in ~/.local/share/Steam.
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;             # Steam Remote Play
    localNetworkGameTransfers.openFirewall = true;
    dedicatedServer.openFirewall = false;       # only for hosting game servers

    # extra Proton builds, pick one per game under Properties > Compatibility
    extraCompatPackages = [ pkgs.proton-ge-bin ];

    gamescopeSession.enable = true;             # "Steam (gamescope)" session, also handy as a wrapper
  };

  # per-game boost: set the launch option to `gamemoderun %command%`
  programs.gamemode.enable = true;

  # 32-bit graphics libraries, which many games still need
  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    mangohud        # overlay: launch option `mangohud %command%`
    protontricks    # fix up Proton prefixes
  ];
}
