{ pkgs, ... }:
{
  imports = [
    ./apps
    ./hyprland.nix
    ./keys.nix
    ./quickshell.nix
    ./terminal.nix
    ./dolphin.nix
    ./bluetooth.nix
    ./default-apps.nix
    ./app-icons.nix
    ./obs.nix
    ./player-art.nix
    ./idle.nix
    ./file-manager.nix
    ./pictures.nix
    ./browsers.nix
    ./fastfetch.nix
    ./desktop-entries.nix
  ];

  home.username = "frozen";
  home.homeDirectory = "/home/frozen";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    libnotify
    python3
    unzip
  ];

  programs.home-manager.enable = true;

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings.git_protocol = "https";      # what `gh auth login` tried to write
  };

  # Commit name and email live in ~/.config/git/identity, which is not part of this repo.
  # Git ignores the include if the file is missing. Create it once (see the command in the README or chat).
  programs.git = {
    enable = true;
    includes = [ { path = "~/.config/git/identity"; } ];
  };

  stylix.targets.qt = {
    enable = true;
    platform = "kde";
  };

  stylix.targets.kde = {
    enable = true;
    useWallpaper = false;
  };

  # hyprpaper is replaced by the Quickshell wallpaper layer (components/wallpaper)

  # Night light daemon, driven by the Display window (hyprctl hyprsunset ...)
  services.hyprsunset.enable = true;

  # Input Remapper: apply the saved presets at login. The system service (modules/applications/
  # input-remapper.nix) may still be starting, so a failed try is repeated a few times.
  systemd.user.services.input-remapper-autoload = {
    Unit = {
      Description = "Apply Input Remapper presets";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.input-remapper}/bin/input-remapper-control --command autoload";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.systemDirs.data = [
    "/etc/profiles/per-user/frozen/share"
  ];
}
