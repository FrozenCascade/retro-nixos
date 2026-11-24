{ pkgs, ... }:

# Lution, the Sober bootstrapper. It is a ready-made program (a single static executable), not packaged in nixpkgs,
# so this runs it from the folder below. Put the file there once:
#   install -Dm755 ~/Downloads/Lution-x86_64 ~/Applications/Lution/Lution-x86_64
# Its name, icon and description for the launcher, bar and dock are in settings.nix (apps."lution").
let
  program = "$HOME/Applications/Lution/Lution-x86_64";      # change this if you keep the file elsewhere

  launcher = pkgs.writeShellScriptBin "lution" ''
    if [ ! -x "${program}" ]; then
      ${pkgs.libnotify}/bin/notify-send "Lution" "Put the executable at ${program} (and make it executable)"
      exit 1
    fi
    export PATH="${pkgs.bubblewrap}/bin:/run/current-system/sw/bin:$PATH"
    exec ${pkgs.steam-run}/bin/steam-run "${program}" "$@"
  '';
in
{
  environment.systemPackages = [
    launcher
    (pkgs.makeDesktopItem {
      name = "lution";
      desktopName = "Lution";
      comment = "Sober Bootstrapper";
      exec = "lution";
      icon = "lution";
      categories = [ "Game" ];
    })
  ];
}
