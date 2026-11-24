{ pkgs, inputs, ... }:

# Media apps with a Super shortcut (home/frozen/hypr/shortcuts.lua). Their menu names are in settings.nix (apps).
#
# Spotify comes from spicetify-nix: the normal Spotify with Spicetify applied (theme and extensions). It is still
# called "spotify" (command, menu entry, window class, icon), so nothing else in the config changes.
# Do not also install pkgs.spotify anywhere: this module installs it.
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Gruvify ships its style as Sass; it is compiled once at build time
  gruvify = pkgs.runCommand "gruvify" { nativeBuildInputs = [ pkgs.dart-sass ]; } ''
    cp -r ${inputs.gruvify} $out
    chmod -R u+w $out
    sass --no-source-map $out/user.sass $out/user.css
  '';
in
{
  imports = [ inputs.spicetify-nix.nixosModules.spicetify ];

  environment.systemPackages = [
    pkgs.freetube              # YouTube client
    pkgs.jellyfin-desktop      # Jellyfin client (Qt), Super + J
    pkgs.kdePackages.kamoso    # webcam: pictures and video
  ];

  programs.spicetify = {
    enable = true;
    theme = {
      name = "Gruvify";
      src = gruvify;
      appendName = false;      # the theme files are at the top of the folder
    };

    # Extensions: names from spicePkgs.extensions, for example shuffle, hidePodcasts, adblockify
    enabledExtensions = with spicePkgs.extensions; [ ];
  };

  # Stylix would otherwise theme Spotify with the system palette, on top of Gruvify
  stylix.targets.spicetify.enable = false;
}
