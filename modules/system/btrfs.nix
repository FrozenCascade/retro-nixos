{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.btrfs-progs pkgs.compsize pkgs.btrfs-assistant ];

  # monthly checksum verification of the whole filesystem
  services.btrfs.autoScrub = { enable = true; interval = "monthly"; fileSystems = [ "/" ]; };

  # timeline snapshots of /home (the .snapshots subvolume is created at install time)
  # change the TIMELINE_LIMIT_* numbers to keep more or fewer of each kind
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "frozen" ];
    SYNC_ACL = true;
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 6;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 3;
    TIMELINE_LIMIT_YEARLY = 0;
  };
}
