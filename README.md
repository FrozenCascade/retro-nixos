# nixos-config

A NixOS flake for one laptop: Hyprland (configured in Lua), Home Manager, Stylix with Gruvbox, and a
retro warm-industrial shell written in Quickshell. It aims at KDE-like function with a calm,
easy-on-the-eyes look, and tries to stay light on memory and GPU.

<!-- add a screenshot or two here: docs/bar.png, docs/launcher.png -->

## What is in it

- **Shell** (`home/frozen/quickshell`): top bar, launcher, calendar and planner, audio, display,
  connections, session and lock windows, screenshot and recording tools, a weather radar.
- **Hyprland** (`home/frozen/hypr`): split into small Lua files (binds, rules, workspaces, look).
- **System** (`modules/`): desktop, hardware, apps, and optional pieces such as fingerprint login,
  a VPN-bypass launcher and Secure Boot (off until you enable it).
- **One settings file** (`home/frozen/settings.nix`): monitors, keyboard layouts, workspace names and
  the app table (names, icons, categories) shared by Hyprland and Quickshell.

## Using it

This is one person's config, so treat it as a source of ideas or fork it and edit. To try it:

1. Change the user: `home/frozen/` and `modules/system/users.nix` (search the repo for `frozen`).
2. Replace `hosts/elitebook/hardware-configuration.nix` with your own (`nixos-generate-config`).
3. Set hostname, time zone and boot loader in `hosts/elitebook/default.nix`.
4. Set your monitor names and layouts in `home/frozen/settings.nix`.
5. Apply it:

   ```
   sudo nixos-rebuild switch --flake .#nixos
   ```

The Quickshell files are linked live from `~/nixos-config`, so QML edits only need a shell restart:

```
pkill -f quickshell; sleep 2; setsid -f uwsm app -- env QS_ICON_THEME=Gruvbox-Plus-Dark quickshell
```

If you clone it somewhere else, change `repoDir` in `home/frozen/quickshell.nix`.

## Notes

- Built on NixOS 26.05 (`nixos-26.05`) and Quickshell 0.3, tested on a single machine
  (HP EliteBook, Intel graphics). Other hardware may need changes.
- The weather map uses CARTO tiles, which need a free key. Put it in `~/.config/carto-basemaps.key`.
  It is read at runtime and never stored in the repo.
- Git identity, API keys and the Secure Boot keys (`/var/lib/sbctl`) live outside the repo on purpose.

## License

MIT, see `LICENSE`.
