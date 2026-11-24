{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.nm-applet.enable = true;

  environment.systemPackages = with pkgs; [
  kitty fuzzel
  quickshell
  hyprpolkitagent   # auth prompts (fits Quickshell later too)
  brightnessctl
  playerctl
  wl-clipboard
  qalculate-qt
];

fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
