{ config, pkgs, ... }:

# Fingerprint login, the way KDE does it: the reader unlocks the lock screen and answers the password
# question of sudo and of graphical "authenticate" windows. Passwords keep working everywhere.
#
# Needs a reader libfprint knows. Check with:  lsusb ; fprintd-list $USER
# Fingers are added in the Session window (FINGERPRINT button next to CHANGE ICON).
{
  services.fprintd.enable = true;

  security.pam.services = {
    # fingerprint first, the password prompt follows after a few failed scans
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;

    # Turning on fprintd would otherwise add the reader to every service. These two keep password-only:
    # the lock screen's password box must never wait for the reader, and the login screen cannot show
    # a "touch the reader" prompt.
    quickshell-lock.fprintAuth = false;
    sddm.fprintAuth = false;
    login.fprintAuth = false;

    # the lock screen's second, fingerprint-only check (components/lock/LockScreen.qml runs it next to the
    # password one, so you can type or touch, whichever comes first)
    quickshell-lock-fprint.text = ''
      auth     required  ${config.services.fprintd.package}/lib/security/pam_fprintd.so
      account  required  pam_permit.so
      session  required  pam_permit.so
    '';
  };
    # The Synaptics reader (06cb:00f0) drops off USB with autosuspend and often after sleep.
  # Keep it powered, and re-enumerate it on wake. Another sensor: change the ids (see lsusb).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00f0", ATTR{power/control}="on"
  '';

  powerManagement.resumeCommands = ''
    for v in /sys/bus/usb/devices/*/idVendor; do
      [ "$(${pkgs.coreutils}/bin/cat "$v")" = "06cb" ] || continue
      d=''${v%/idVendor}
      echo 0 > "$d/authorized"; ${pkgs.coreutils}/bin/sleep 1; echo 1 > "$d/authorized"
    done
  '';
}
