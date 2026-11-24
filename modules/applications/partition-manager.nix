{ pkgs, ... }:

# KDE Partition Manager. It cannot change mounted partitions, so use a live USB for the root and boot ones.
{
  programs.partition-manager.enable = true;

  # the tools it calls for each filesystem type
  environment.systemPackages = with pkgs; [
    dosfstools      # FAT32 (boot partitions)
    ntfs3g          # NTFS (Windows)
    e2fsprogs       # ext4
    exfatprogs
    btrfs-progs
  ];
}
