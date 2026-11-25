{ config, lib, pkgs, ... }:
let
  settings = import ./settings-load.nix { inherit lib; };

  # Live = ~/.config/quickshell links straight to the repo, so QML edits apply
  # instantly (Quickshell hot-reloads). Set false to copy into the Nix store instead.
  live = true;
  repoDir = "${config.home.homeDirectory}/nixos-config/home/frozen/quickshell";
    aiDir = "${config.home.homeDirectory}/nixos-config/home/frozen/ai-browser";
  aiPython = pkgs.python3.withPackages (ps: [ ps.pyside6 ]);
  aiBrowser = pkgs.writeShellScriptBin "qs-ai-browser" ''
    export QT_QPA_PLATFORM=wayland
    export QML_IMPORT_PATH=${lib.makeSearchPath "lib/qt-6/qml" [ pkgs.qt6.qtdeclarative pkgs.qt6.qtwebengine ]}
    export QT_PLUGIN_PATH=${lib.makeSearchPath "lib/qt-6/plugins" [ pkgs.qt6.qtbase pkgs.qt6.qtwayland pkgs.qt6.qtwebengine ]}
    if [ "$1" = toggle ] && ${pkgs.procps}/bin/pkill -USR1 -f ai-browser/browser.py; then exit 0; fi
    exec ${aiPython}/bin/python ${aiDir}/browser.py "$@"
  '';

  c = config.lib.stylix.colors;
  fonts = config.stylix.fonts;

  baseNames = [
    "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07"
    "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F"
  ];
  baseProps = lib.concatMapStringsSep "\n"
    (n: "  readonly property color ${n}: \"#${c.${n}}\"") baseNames;

  # Generated from Nix; QML reads it as the singleton `Theme`
  themeQml = ''
    pragma Singleton
    import QtQuick
    import Quickshell

    Singleton {
    ${baseProps}

      // Roles (gruvbox/base16 convention)
      readonly property color bg:     base00
      readonly property color bgAlt:  base01
      readonly property color bgSel:  base02
      readonly property color fgDim:  base03
      readonly property color fg:     base05
      readonly property color red:    base08
      readonly property color orange: base09
      readonly property color yellow: base0A
      readonly property color green:  base0B
      readonly property color aqua:   base0C
      readonly property color blue:   base0D
      readonly property color purple: base0E

      readonly property string fontMono: "BlexMono Nerd Font"
      readonly property string fontSans: "${fonts.sansSerif.name}"
      readonly property real   fontSize: ${toString fonts.sizes.desktop}
    }
  '';

  # Highest CPU temperature in °C. Reads the CPU hwmon sensors (Intel coretemp, AMD k10temp),
  # falling back to the thermal zones.
  cpuTempScript = pkgs.writeShellScript "cpu-temp" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    max=0
    for h in /sys/class/hwmon/hwmon*; do
      case "$(cat "$h/name" 2>/dev/null)" in
        coretemp|k10temp|zenpower|cpu_thermal)
          for t in "$h"/temp*_input; do
            v=$(cat "$t" 2>/dev/null || echo 0)
            [ "$v" -gt "$max" ] && max=$v
          done ;;
      esac
    done
    if [ "$max" -eq 0 ]; then
      for z in /sys/class/thermal/thermal_zone*; do
        case "$(cat "$z/type" 2>/dev/null)" in
          x86_pkg_temp|acpitz)
            v=$(cat "$z/temp" 2>/dev/null || echo 0)
            [ "$v" -gt "$max" ] && max=$v ;;
        esac
      done
    fi
    echo $((max / 1000))
  '';

  # The sensor files cpuTempScript would read, one path per line. The shell reads them itself (SysfsPoll),
  # which is cheaper than running the script every few seconds. Same sensors, same fallback.
  cpuTempFilesScript = pkgs.writeShellScript "cpu-temp-files" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    found=0
    for h in /sys/class/hwmon/hwmon*; do
      case "$(cat "$h/name" 2>/dev/null)" in
        coretemp|k10temp|zenpower|cpu_thermal)
          for t in "$h"/temp*_input; do
            [ -r "$t" ] && { echo "$t"; found=1; }
          done ;;
      esac
    done
    if [ "$found" = 0 ]; then
      for z in /sys/class/thermal/thermal_zone*; do
        case "$(cat "$z/type" 2>/dev/null)" in
          x86_pkg_temp|acpitz) echo "$z/temp" ;;
        esac
      done
    fi
  '';

  # Monitors and workspace count, shared with Hyprland (see settings.nix)
  settingsQml = ''
    pragma Singleton
    import Quickshell

    Singleton {
      readonly property string externalMonitor: "${settings.externalMonitor}"
      readonly property string laptopMonitor:   "${settings.laptopMonitor}"
      readonly property string laptopWorkspace: "${settings.laptopWorkspace}"
      readonly property int    workspaceCount:  ${toString settings.workspaceCount}
      readonly property var    keyboardLayouts: ${builtins.toJSON settings.keyboardLayouts}
      readonly property var    appCategories: ${builtins.toJSON (lib.mapAttrs (_: a: a.categories or [ ]) (settings.apps or { }))}
      readonly property var    apps: ${builtins.toJSON (settings.apps or { })}

      // Shown on the bar buttons, overview and blip. Optional: Desktop.qml has fallbacks.
      readonly property var    workspaceNames:  ${builtins.toJSON settings.workspaceNames}
      readonly property var    laptopName:      ${builtins.toJSON (settings.laptopName or null)}

      // Bar and popups (settings.nix: bar, osd)
      readonly property real   barHeight:       ${toString settings.bar.height}
      readonly property real   barRevealHeight: ${toString settings.bar.revealHeight}
      readonly property int    osdVisibleMs:    ${toString settings.osd.visibleMs}

      // The Stylix wallpaper, used by the lock screen
      readonly property string wallpaper:       "${toString config.stylix.image}"
    }
  '';

  # cava prints its bars as plain text for the wallpaper (WallpaperState.qml reads it)
  cavaConfig = pkgs.writeText "cava-wallpaper.conf" ''
    [general]
    bars = 48
    framerate = 30

    [input]
    method = pipewire
    source = auto

    [output]
    method = raw
    raw_target = /dev/stdout
    data_format = ascii
    ascii_max_range = 100
    bar_delimiter = 59
    frame_delimiter = 10
  '';

  # Programs the Studio window runs (home/frozen/studio.nix)
  studio = import ./studio.nix { inherit lib pkgs; };

  # Exact tool paths from Nix, so QML never depends on PATH
  toolsQml = ''
    pragma Singleton
    import Quickshell

    Singleton {
      readonly property string qalc:    "${pkgs.libqalculate}/bin/qalc"
      readonly property string wlCopy:  "${pkgs.wl-clipboard}/bin/wl-copy"
      readonly property string cpuTemp: "${cpuTempScript}"
      readonly property string cpuTempFiles: "${cpuTempFilesScript}"
      readonly property string curl:    "${pkgs.curl}/bin/curl"
      readonly property string fprintd: "${pkgs.fprintd}/bin"
      readonly property string ytDlp:   "${pkgs.yt-dlp}/bin/yt-dlp"
      readonly property string cliphist: "${pkgs.cliphist}/bin/cliphist"
      readonly property string htop:    "${pkgs.htop}/bin/htop"
      readonly property string notifySend: "${pkgs.libnotify}/bin/notify-send"
      readonly property string timedatectl: "${pkgs.systemd}/bin/timedatectl"
      readonly property string stat: "${pkgs.coreutils}/bin/stat"
      readonly property string aiBrowser: "${aiBrowser}/bin/qs-ai-browser"
      readonly property string studioShot: "${studio.shot}/bin/studio-shot"
      readonly property string studioRecord: "${studio.record}/bin/studio-record"
      readonly property string studioObs: "${studio.obs}/bin/studio-obs"
      readonly property string studioDownload: "${studio.download}/bin/studio-download"
      readonly property string studioPlayer: "${studio.player}/bin/studio-player"
      readonly property string python: "${pkgs.python3}/bin/python3"
      readonly property string cava: "${pkgs.cava}/bin/cava"
      readonly property string cavaConfig: "${cavaConfig}"
      readonly property string nmcli: "${pkgs.networkmanager}/bin/nmcli"
      readonly property string busctl: "${pkgs.systemd}/bin/busctl"
      readonly property string kdeconnectCli: "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-cli"
      readonly property string brightnessctl: "${pkgs.brightnessctl}/bin/brightnessctl"
      readonly property string ddcutil: "${pkgs.ddcutil}/bin/ddcutil"
      readonly property string distroLogo: "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg"
      readonly property string iconTheme: "${config.stylix.icons.package}/share/icons/${config.stylix.icons.dark}"
    }
  '';

  # One link per top-level file/folder in the repo's quickshell/ directory
  link = name:
    if live
    then config.lib.file.mkOutOfStoreSymlink "${repoDir}/${name}"
    else ./quickshell + "/${name}";

  qmlLinks = lib.mapAttrs'
    (name: _: lib.nameValuePair "quickshell/${name}" { source = link name; })
    (builtins.readDir ./quickshell);
in
{
  home.packages = [ pkgs.libqalculate aiBrowser ];

  xdg.configFile = qmlLinks // {
    "quickshell/Theme.qml".text = themeQml;
    "quickshell/Tools.qml".text = toolsQml;
    "quickshell/Settings.qml".text = settingsQml;
  };
}
