{ pkgs, lib, ... }:

# Suspends the laptop when nobody has logged in for a while: the login screen (SDDM) cannot run hypridle,
# so this watches from the system side. Once someone is logged in it does nothing, and idle.nix takes over.
# It counts time at the login screen, not keyboard activity, so a very slow login after the limit still sleeps.
let
  minutes = 5;                                        # change this to taste

  watch = pkgs.writeShellScript "sddm-sleep" ''
    PATH=${lib.makeBinPath [ pkgs.systemd pkgs.coreutils ]}
    waited=0
    while true; do
      sleep 30
      user=0
      for id in $(loginctl --no-legend list-sessions | while read -r id _; do echo "$id"; done); do
        [ "$(loginctl show-session "$id" -p Class --value)" = user ] && user=1
      done
      if [ "$user" = 1 ]; then
        waited=0
      else
        waited=$((waited + 30))
      fi
      if [ "$waited" -ge ${toString (minutes * 60)} ]; then
        waited=0
        systemctl suspend
      fi
    done
  '';
in
{
  systemd.services.sddm-sleep = {
    description = "Suspend after ${toString minutes} minutes at the login screen";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${watch}";
      Restart = "always";
    };
  };
}
