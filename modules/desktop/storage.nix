{ ... }:

# Mounting drives from a file manager (Dolphin): udisks does the mounting, polkit decides who may.
# Unlocking an encrypted drive (LUKS, for example a Fedora disk) asks for authorization, which needs a polkit
# agent running in the session; that part is home/frozen/dolphin.nix.
{
  services.udisks2.enable = true;
  security.polkit.enable = true;
}
