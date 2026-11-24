{ pkgs, ... }:

# System pieces the Quickshell windows lean on: phones, screen brightness, the Proton VPN app and the keyboard.
# (Wi-Fi, Bluetooth and sound are set up in hosts/elitebook and hardware.nix.)
{
  # KDE Connect: the daemon, kdeconnect-cli, and the firewall ports phones need
  programs.kdeconnect.enable = true;

  # Brightness of the laptop panel (brightnessctl is installed in modules/desktop/hyprland.nix):
  # its udev rules (listed with the keyboard rule below) let the "video" group change it without root
  # Keyboard lighting: the logged-in user may talk to the NuPhy Air96 V2's raw HID interface
  # (components/bar/display/KeyboardTab.qml). Find the ids of another keyboard with lsusb.
  # This has to be a numbered rules file ahead of 73 (udev only grants "uaccess" before then),
  # which services.udev.extraRules is not: that one is read last.
  services.udev.packages = [
    pkgs.brightnessctl
    (pkgs.writeTextDir "lib/udev/rules.d/70-nuphy-hidraw.rules" ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="3265", TAG+="uaccess"
    '')
  ];

  # Brightness of external monitors over DDC/CI. i2c-dev gives ddcutil its device files,
  # the "i2c" group lets you use them. A monitor behind an HDMI splitter will not answer;
  # the Display window then dims it in software.
  hardware.i2c.enable = true;

  users.users.frozen.extraGroups = [ "video" "i2c" ];

  environment.systemPackages = with pkgs; [
    ddcutil
    protonvpn-gui
    sshfs             # "OPEN FILES" in the Phones tab mounts the phone with it
  ];
}
