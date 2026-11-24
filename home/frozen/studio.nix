{ lib, pkgs }:

# Small programs the Studio window runs. quickshell.nix imports this and puts their paths in Tools.qml.
# Each one is a script from ./studio with its tools on PATH, so QML never depends on what is installed.
let
  # a script from ./studio, with these packages on PATH
  script = name: file: tools: pkgs.writeShellScriptBin name ''
    # /run/wrappers/bin first: programs like gpu-screen-recorder only work through their NixOS wrapper
    export PATH=/run/wrappers/bin:${lib.makeBinPath tools}:$PATH
    ${builtins.readFile file}
  '';
in
{
  # screenshots (components/bar/studio/CaptureTab.qml, Print keys in hypr/studio.lua)
  shot = script "studio-shot" ./studio/shot.sh (with pkgs; [ grim slurp jq hyprland wl-clipboard libnotify coreutils kdePackages.kdialog imagemagick ]);

  # screen recording (RecordTab.qml). The program needs the wrapper that programs.gpu-screen-recorder
  # sets up in modules/system/studio.nix to capture the screen.
  record = script "studio-record" ./studio/record.sh (with pkgs; [ gpu-screen-recorder slurp libnotify coreutils mpv kdePackages.kdialog ]);

  # OBS Studio's recording state and stop, through its WebSocket server (StudioRecorder.qml, obs-record.py)
  obs = pkgs.writeShellScriptBin "studio-obs" ''
    exec ${pkgs.python3}/bin/python3 ${./studio/obs-record.py} "$@"
  '';

  # yt-dlp for the DOWNLOAD tab (DownloadTab.qml)
  download = script "studio-download" ./studio/download.sh (with pkgs; [ yt-dlp deno ffmpeg atomicparsley wl-clipboard libnotify xdg-utils coreutils ]);

  # the playlist player (LibraryTab.qml): mpv with the MPRIS script, so it shows up in the bar and the
  # PLAYER tab like any other player. It starts without a window and is controlled over a socket.
  player = pkgs.writeShellScriptBin "studio-player" ''
    mkdir -p "''${XDG_RUNTIME_DIR:-/tmp}/studio"
    exec ${pkgs.mpv.override { scripts = [ pkgs.mpvScripts.mpris ]; }}/bin/mpv \
      --no-video --idle=yes --no-terminal --audio-display=no --force-window=no \
      --input-ipc-server="''${XDG_RUNTIME_DIR:-/tmp}/studio/mpv.sock" "$@"
  '';
}
