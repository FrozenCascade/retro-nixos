{ config, lib, pkgs, ... }:

# The login screen: the shell's lock screen as an SDDM theme (see sddm/theme). It lists the users
# (switch user) and the installed sessions (choose the desktop), and shows the battery in its title bar.
# Colours come from Stylix, so a new base16 scheme changes this screen too.
let
  hm = config.home-manager.users.${owner};
  c = (hm.lib.stylix or { }).colors or config.lib.stylix.colors;      # the shell's colours, not the system-wide default
  owner = "frozen";                                  # the user who picks the login picture
  mono = "BlexMono Nerd Font";                       # keep equal to Theme.fontMono in quickshell.nix
  image = config.stylix.image or null;               # the desktop wallpaper, used as the backdrop

  # the theme folder plus the two generated pieces: the colours and the wallpaper
  palette = pkgs.writeText "Palette.qml" ''
    pragma Singleton
    import QtQuick

    QtObject {
      readonly property color bg: "#${c.base00}"
      readonly property color bgAlt: "#${c.base01}"
      readonly property color bgSel: "#${c.base02}"
      readonly property color fgDim: "#${c.base03}"
      readonly property color fg: "#${c.base05}"
      readonly property color red: "#${c.base08}"
      readonly property color orange: "#${c.base09}"
      readonly property color yellow: "#${c.base0A}"
      readonly property string fontMono: "${mono}"
      readonly property real fontSize: ${toString config.stylix.fonts.sizes.desktop}

      readonly property real corner: 3
      readonly property real shadowOffset: 4
      readonly property real borderWidth: 2
      readonly property color shadow: Qt.rgba(0, 0, 0, 0.6)
      readonly property color inset: Qt.rgba(0, 0, 0, 0.35)
    }
  '';

  theme = pkgs.runCommand "sddm-theme-retro" { } ''
    dir=$out/share/sddm/themes/retro
    mkdir -p $dir
    cp -r ${./sddm/theme}/. $dir/
    chmod -R u+w $dir
    cp ${palette} $dir/style/Skin.qml
    ${lib.optionalString (image != null) "cp ${image} $dir/background"}
  '';

  # Battery numbers for the greeter, as a tiny QML file it can load. Works with either the
  # energy_* (µWh, µW) or charge_* (µAh, µA) files the kernel offers.
  batteryJob = pkgs.writeShellScript "sddm-battery" ''
    PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    out=/run/sddm-battery/Battery.qml
    bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)

    present=false percent=0 status=Unknown seconds=0
    if [ -n "$bat" ]; then
      present=true
      percent=$(cat "$bat/capacity" 2>/dev/null || echo 0)
      status=$(cat "$bat/status" 2>/dev/null || echo Unknown)
      for kind in energy charge; do
        [ -r "$bat/''${kind}_now" ] || continue
        now=$(cat "$bat/''${kind}_now"); full=$(cat "$bat/''${kind}_full")
        rate=$(cat "$bat/power_now" 2>/dev/null || cat "$bat/current_now" 2>/dev/null || echo 0)
        rate=''${rate#-}
        if [ "$rate" -gt 0 ]; then
          case "$status" in
            Discharging) seconds=$(( now * 3600 / rate )) ;;
            Charging) seconds=$(( (full - now) * 3600 / rate )) ;;
          esac
        fi
        break
      done
    fi

    cat > "$out.tmp" <<QML
    import QtQuick
    QtObject {
      readonly property bool present: $present
      readonly property int percent: $percent
      readonly property string status: "$status"
      readonly property int seconds: $seconds
    }
    QML
    mv "$out.tmp" "$out"
    chmod 644 "$out"
  '';
in
{
  services.displayManager.sddm = {
    theme = "retro";
    extraPackages = [ pkgs.kdePackages.qtdeclarative ];     # QtQuick.Effects for the blur
  };

  environment.systemPackages = [ theme ];

  # the battery file the greeter reads, refreshed every 30 seconds
  systemd.tmpfiles.rules = [
    "d /run/sddm-battery 0755 root root -"
    "R /var/lib/sddm/.cache - - - - -"                           # stale compiled theme
    "d /var/lib/sddm-retro 0775 ${owner} users -"                # the login picture, written by the shell
  ];

  systemd.services.sddm-battery = {
    description = "Battery numbers for the login screen";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = batteryJob;
    };
  };

  systemd.timers.sddm-battery = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1s";
      OnUnitActiveSec = "30s";
    };
  };
}
