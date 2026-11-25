{ config, lib, pkgs, ... }:

# Launcher entries for the apps listed in settings.nix (`apps`). Apps often ship an entry we cannot edit
# (Flatpak, other packages), so this writes a copy into ~/.local/share/applications, which wins over the
# system ones, with the name, icon and description from settings.nix swapped in. The command stays as
# the app made it. The bar, dock and overview read the same table (Desktop.override in the shell).
# It runs at every login, so apps that finish installing later get their entry too.
let
  apps = (import ./settings-load.nix { inherit lib; }).apps;

  # only apps that change something in the entry
  changed = lib.filterAttrs (_: a: a ? icon || a ? name || a ? comment || (a.bypassVpn or false) || (a.onlyCategories or false)) apps;

  pack = "${config.stylix.icons.package}/share/icons/${config.stylix.icons.dark}";

  # where an app's own entry can be: Flatpak, the system, your profile
  sources = [
    "/var/lib/flatpak/exports/share/applications"
    "/run/current-system/sw/share/applications"
    "/etc/profiles/per-user/${config.home.username}/share/applications"
  ];

  # the icon file for a name: never a symbolic one, an apps folder first, and the largest size
  # (the scalable folder sorts last, so it wins when there is one)
  perApp = lib.concatStrings (lib.mapAttrsToList (id: app: ''
    entry=""
    for dir in ${lib.concatStringsSep " " sources}; do
      if [ -f "$dir/${id}.desktop" ]; then entry="$dir/${id}.desktop"; break; fi
    done
    # a shortcut the app keeps in the target folder itself (Steam) is edited in place
    if [ -z "$entry" ] && [ -f "$target/${id}.desktop" ]; then
      entry="$target/${id}.desktop"
    fi
    if [ -z "$entry" ]; then
      echo "app-icons: ${id} is not installed yet, skipping"
    else
      [ "$entry" = "$target/${id}.desktop" ] || cp --no-preserve=mode "$entry" "$target/${id}.desktop"
      ${lib.optionalString (app ? icon) ''
        all="$(find -L ${pack} -name '${app.icon}.svg' | grep -v -i symbolic | sort -V)"
        file="$(printf '%s\n' "$all" | grep '/apps/' | tail -n 1)"
        [ -n "$file" ] || file="$(printf '%s\n' "$all" | tail -n 1)"
        if [ -n "$file" ]; then
          sed -i "s|^Icon=.*|Icon=$file|" "$target/${id}.desktop"
        else
          echo "app-icons: ${app.icon}.svg is not in the icon pack"
        fi
      ''}
      ${lib.optionalString (app ? name) ''
        sed -i -e '/^Name\[/d' -e "s|^Name=.*|Name=${app.name}|" "$target/${id}.desktop"
      ''}
      ${lib.optionalString (app.bypassVpn or false) ''
        sed -i '/^Exec=vpn-bypass /! s|^Exec=|Exec=vpn-bypass |' "$target/${id}.desktop"
      ''}
      ${lib.optionalString ((app.onlyCategories or false) && app ? categories) ''
        sed -i "s|^Categories=.*|Categories=${lib.concatStringsSep ";" app.categories};|" "$target/${id}.desktop"
      ''}
      ${lib.optionalString (app ? comment) ''
        sed -i '/^Comment\[/d' "$target/${id}.desktop"
        if grep -q '^Comment=' "$target/${id}.desktop"; then
          sed -i "s|^Comment=.*|Comment=${app.comment}|" "$target/${id}.desktop"
        else
          # entries made by hand have no description line: add one under the first Name=
          sed -i "0,/^Name=/s|^Name=.*|&\nComment=${app.comment}|" "$target/${id}.desktop"
        fi
      ''}
    fi
  '') changed);

  script = pkgs.writeShellScript "app-icons" ''
    PATH=${lib.makeBinPath [ pkgs.findutils pkgs.gnused pkgs.gnugrep pkgs.coreutils ]}
    target="$HOME/.local/share/applications"
    mkdir -p "$target"
    ${perApp}
  '';
in
{
  systemd.user.services.app-icons = {
    Unit = {
      Description = "Names and icons from settings.nix for launcher entries";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${script}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
