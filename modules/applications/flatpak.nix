{ pkgs, ... }:

# Flatpak with the Flathub store. Add an app by putting its ID in `apps` below; the next rebuild installs it
# in the background, so a slow download never holds up `nixos-rebuild`. Look IDs up at https://flathub.org
# (the ID is the last part of the app's address). Remove apps by hand: `flatpak uninstall <id>`.
let
  apps = [
    "org.vinegarhq.Sober"             # Roblox
    "org.vinegarhq.Vinegar"           # Roblox Studio
    "org.prismlauncher.PrismLauncher" # Minecraft Java
    "io.mrarm.mcpelauncher"           # Minecraft Bedrock
  ];
in
{
  services.flatpak.enable = true;

  # file pickers and "open with" dialogs inside Flatpak apps
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  systemd.services.flatpak-apps = {
    description = "Install the Flatpak apps listed in modules/applications/flatpak.nix";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak ];

    # Type=simple: the rebuild does not wait for the downloads. Retries cover an offline boot.
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 120;
    };

    script = ''
      flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak install --system --noninteractive --or-update flathub ${builtins.concatStringsSep " " apps}
      # The session's Qt style variable (set by the theme) breaks the Qt apps' own bundled Qt; they quit at startup
      flatpak override --system --unset-env=QT_STYLE_OVERRIDE
    '';
  };
}
