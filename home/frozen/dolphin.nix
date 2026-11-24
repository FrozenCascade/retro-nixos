{ config, lib, pkgs, ... }:

# Dolphin outside Plasma: which terminal "Open Terminal" uses, and the activity service it can talk to.
{
  # ---- terminal ----
  # KDE programs read their terminal from kdeglobals. Stylix may keep that file as a read-only link, so the
  # activation first turns it into a normal file when needed, then sets the two keys. Restart Dolphin after a switch.
  home.activation.kdeTerminal = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config="$HOME/.config/kdeglobals"
    if [ -L "$config" ]; then
      run cp --remove-destination "$(readlink -f "$config")" "$config"
      run chmod u+w "$config"
    fi
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
  '';

  # ---- colors, style and icons ----
  # Stylix applies these with plasma-apply-lookandfeel, which only exists inside a Plasma session, so on
  # Hyprland nothing wrote them. This step does the same job: it names the scheme, copies the scheme's
  # [Colors:*] groups into kdeglobals (the file view and other KDE widgets read their colors from there)
  # and sets the widget style and icon theme. Restart Dolphin after a switch.
  home.activation.kdeTheme = lib.hm.dag.entryAfter [ "kdeTerminal" ] ''
    config="$HOME/.config/kdeglobals"
    # Stylix's scheme is the one .colors file in the profile that is not part of Breeze
    scheme="$(ls "$newGenPath"/home-path/share/color-schemes/*.colors 2>/dev/null | grep -v '/Breeze' | head -n 1 || true)"
    if [ -n "$scheme" ] && [ -f "$config" ]; then
      tmp="$(mktemp)"
      ${pkgs.gawk}/bin/awk '/^\[/{skip=($0 ~ /^\[Colors:/)} !skip' "$config" > "$tmp"
      ${pkgs.gawk}/bin/awk '/^\[/{p=($0 ~ /^\[Colors:/)} p' "$scheme" >> "$tmp"
      run cp "$tmp" "$config"
      rm -f "$tmp"
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$(basename "$scheme" .colors)"
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group Icons --key Theme ${config.stylix.icons.dark}
    fi
  '';

  # ---- unlocking drives ----
  # Mounting an encrypted drive asks for authorization; Hyprland starts nothing to ask it, so this agent does.
  services.hyprpolkitagent.enable = true;

  # ---- encrypted drives ----
  # Dolphin cannot ask for a passphrase here: it hands that to a KDE service (SolidUiServer) that only runs inside
  # a Plasma session. udiskie asks instead. No tray and no automounting, so nothing pops up at login;
  # the "Unlock Drives" launcher entry (or `udiskie-mount -a` in a terminal) unlocks and mounts what is plugged in.
  # Once a drive is unlocked, Dolphin lists and mounts it like any other.
  services.udiskie = {
    enable = true;
    automount = false;
    notify = true;
    tray = "never";
    settings = {
      program_options.password_prompt = "builtin:gui";

      # udiskie skips partitions on internal disks (it is made for USB drives). Each internal encrypted
      # partition to unlock from here is listed by UUID: the one on the "crypto" line of `lsblk -f`.
      device_config = [
        { id_uuid = "b5007ac0-6762-4651-a4ff-764f661b305a"; ignore = false; }   # Fedora
      ];
    };
  };

  xdg.desktopEntries.unlock-drives = {
    name = "Unlock Drives";
    genericName = "Encrypted Drives";
    comment = "Unlock and mount encrypted and unmounted drives";
    exec = "${pkgs.udiskie}/bin/udiskie-mount -a";
    icon = "drive-harddisk";
    categories = [ "System" "Utility" ];
  };

  # ---- activities ----
  # Plasma normally starts this background service (it keeps the list of activities and recently used files).
  # Dolphin finds it over D-Bus; without Plasma nothing starts it, so it runs as a user service here.
  systemd.user.services.kactivitymanagerd = {
    Unit = {
      Description = "KDE activity manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.kactivitymanagerd}/bin/kactivitymanagerd";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = [ pkgs.kdePackages.kactivitymanagerd pkgs.udiskie ];
}
