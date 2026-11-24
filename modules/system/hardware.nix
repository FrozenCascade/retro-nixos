{ config, pkgs, ... }:

{
  # Enable CUPS to print documents.
  services.printing.enable = true;

#   # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable Bluetooth hardware support and the Blueman manager
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Bootloader does not update.
  boot.loader.systemd-boot.graceful = true;
}
