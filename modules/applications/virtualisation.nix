{ pkgs, ... }:
{
  # QEMU/KVM through libvirt, managed with virt-manager.
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      # TPM 2.0 emulation, needed by Windows 11 guests
      swtpm.enable = true;
    };
  };

  # USB passthrough from inside the VM window
  virtualisation.spiceUSBRedirection.enable = true;

  programs.virt-manager.enable = true;

  users.users.frozen.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    virt-viewer       # standalone console window
    spice-gtk         # clipboard and display sharing with guests
  ];
}
