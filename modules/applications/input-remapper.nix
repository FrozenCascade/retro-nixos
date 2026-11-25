{ ... }:

# GUI for remapping mouse buttons, keyboards and controllers (launcher name: Input Remapper).
# Mappings are made in its window and saved in ~/.config/input-remapper-2, outside this repo.
# Presets are applied at login by a user service in home/frozen/default.nix.
{
  services.input-remapper = {
    enable = true;
    enableUdevRules = true;   # applies saved presets again when a device is plugged in or reconnects
  };

  hardware.uinput.enable = true;   # lets the service create the remapped virtual devices
}
