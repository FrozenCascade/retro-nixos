{ ... }:
{
  # Swap file on disk, used when memory is under real pressure
  swapDevices = [
    { device = "/var/lib/swapfile"; size = 8 * 1024; }   # size is in MiB (8 GiB here)
  ];
}
