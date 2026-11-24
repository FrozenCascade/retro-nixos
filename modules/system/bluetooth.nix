{ lib, ... }:

# Keeps Bluetooth devices connected while the screen is locked or idle.
{
  hardware.bluetooth.enable = lib.mkDefault true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault true;

  # the laptop's Bluetooth chip is a USB device, and Linux powers those down when idle, which drops
  # headphones and controllers; this turns that off for the Bluetooth driver
  boot.extraModprobeConfig = "options btusb enable_autosuspend=n";
}
