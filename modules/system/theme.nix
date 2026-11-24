{ pkgs, inputs, lib, ... }:

{
  # Weather Icons font for the weather button
  fonts.packages = [ pkgs.weather-icons pkgs.noto-fonts-cjk-sans pkgs.nerd-fonts.blex-mono ];

  environment.systemPackages = [
    (pkgs.runCommand "cobalt-sound-theme" { } ''
      mkdir -p $out/share/sounds
      cp -r ${inputs.cobalt} $out/share/sounds/cobalt
    '')
  ];
  environment.pathsToLink = [ "/share/sounds" ];

  stylix = {
    enable = true;
    polarity = "dark";

    base16Scheme =
      "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    targets.qt = {
      enable = true;
      platform = lib.mkForce "kde";
    };

    image = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/main/wallpapers/photography/mountain-village.png";
      hash = "sha256-FoDCChLda+SMNQjBD2H+ITTfb6ieB2DVTHjhqA2tWRU=";
    };

    icons = {
      enable = true;

      package = pkgs.gruvbox-plus-icons.overrideAttrs (_: {
        src = inputs.gruvbox-plus;
      });

      dark = "Gruvbox-Plus-Dark";
      light = "Gruvbox-Plus-Light";
    };

    cursor = {
      package = pkgs.capitaine-cursors-themed;
      name = "Capitaine Cursors (Gruvbox)";
      size = 24;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
    };
  };
}
