{ config, lib, pkgs, ... }:

# Two steps after a while without keyboard or mouse. hypridle watches for idleness and does not count while
# something holds an idle inhibitor: the STAY AWAKE switch in the Session window, or a video player.
#   1. lockMinutes: lock the screen only. Everything keeps running, so Bluetooth devices stay connected
#      and music keeps playing.
#   2. suspendMinutes: suspend, unless sound is playing right now.
# `qs ipc call lock sleep` locks first and suspends once the lock is really up (LockState.lockAndSuspend),
# so waking the laptop shows the lock screen, never the desktop.
let
  settings = import ./settings-load.nix { inherit lib; };
  lockMinutes = settings.power.lockMinutes;           # both are set in settings.nix (power)
  suspendMinutes = settings.power.suspendMinutes;

  # hypridle runs these with a bare PATH, so say where `qs` lives
  qs = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:$PATH qs ipc call lock";

  # suspend only when no program is playing sound (an uncorked stream is one that is playing)
  suspendUnlessPlaying = pkgs.writeShellScript "suspend-unless-playing" ''
    if ${pkgs.pulseaudio}/bin/pactl list sink-inputs | ${pkgs.gnugrep}/bin/grep -q "Corked: no"; then
      exit 0
    fi
    ${qs} sleep
  '';
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${qs} lock";                     # loginctl lock-session
        before_sleep_cmd = "${qs} lock";             # a manual suspend also locks
      };

      listener = [
        {
          timeout = lockMinutes * 60;
          on-timeout = "${qs} lock";
        }
        {
          timeout = suspendMinutes * 60;
          on-timeout = "${suspendUnlessPlaying}";
        }
      ];
    };
  };
}
