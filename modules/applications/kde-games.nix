{ pkgs, lib, ... }:

# KDE's games. Add or remove a name below. A name that does not exist in this nixpkgs is skipped
# instead of stopping the rebuild, so a typo just means the game is missing (the names are the
# package names in `kdePackages`, see https://search.nixos.org/packages).
let
  games = [
    "kmines"       # minesweeper
    "kpat"         # patience (solitaire)
    "ksudoku"
    "kmahjongg"
    "kshisen"      # mahjong tile matching
    "kblocks"      # falling blocks
    "klines"
    "kdiamond"
    "kreversi"
    "kigo"         # go
    "kbreakout"
    "granatier"    # bomberman
    "bomber"
    "ksnakeduel"
    "knetwalk"
    "kapman"
    "picmi"        # nonograms
    "palapeli"     # jigsaw puzzles
    "kfourinline"
    "killbots"
  ];
in
{
  environment.systemPackages = builtins.filter (p: p != null) (map (name: pkgs.kdePackages.${name} or null) games);
}
