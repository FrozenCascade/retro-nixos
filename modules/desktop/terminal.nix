{ pkgs, ... }:

# System side of the terminal: kitty is the terminal, and xterm is not installed.
{
  environment.sessionVariables.TERMINAL = "kitty";       # for programs that look for a terminal in the environment

  # xterm comes with the X server by default; neither of these should bring it in
  services.xserver.desktopManager.xterm.enable = false;
  services.xserver.excludePackages = [ pkgs.xterm ];
}
