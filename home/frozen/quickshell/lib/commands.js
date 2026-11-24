.pragma library

// The commands listed in the MISC tab of the calendar window (each block copies on click).
// Add a command: put { title, lines } in a group. Add a group: put { name, items } in the list.
// Titles are shown in capitals. `lines` run top to bottom, so keep a `cd` first when the folder matters.
// Every flake command here assumes the host is called "nixos" (the part after # in .#nixos).

const flake = "cd ~/nixos-config";

// everything in the repo as one text file, for pasting into a chat
const exportLines = [
  flake,
  "{",
  "  echo \"NIXOS CONFIGURATION EXPORT\"; echo \"Source: $PWD\"; echo",
  "  echo \"=== DIRECTORY TREE ===\"; echo",
  "  tree -a -I .git; echo; echo",
  "  echo \"=== FILE CONTENTS ===\"",
  "  find . -path ./.git -prune -o -type f -print | sort | while read -r f; do",
  "    printf '\\n\\n========================================\\nFILE: %s\\n========================================\\n\\n' \"$f\"",
  "    if [ ! -s \"$f\" ] || grep -Iq . \"$f\"; then cat \"$f\"; else echo \"[Binary file: contents skipped]\"; fi",
  "  done",
  "} > ~/nixos-config-export.txt"
];

const groups = [
  {
    name: "REBUILD",
    items: [
      { title: "REBUILD", lines: [flake, "git add -A", "sudo nixos-rebuild switch --flake .#nixos"] },
      { title: "TRY IT, KEEP NOTHING (GONE AT REBOOT)", lines: [flake, "git add -A", "sudo nixos-rebuild test --flake .#nixos"] },
      { title: "APPLY AT THE NEXT START ONLY", lines: [flake, "git add -A", "sudo nixos-rebuild boot --flake .#nixos"] },
      { title: "BUILD ONLY (FINDS ERRORS, CHANGES NOTHING)", lines: [flake, "git add -A", "nixos-rebuild build --flake .#nixos"] },
      { title: "WHAT WOULD CHANGE (AFTER BUILD ONLY)", lines: [flake, "nix store diff-closures /run/current-system ./result"] },
      { title: "REBUILD WITH A FULL ERROR TRACE", lines: [flake, "git add -A", "sudo nixos-rebuild switch --flake .#nixos --show-trace"] },
      { title: "UNDO THE LAST REBUILD", lines: ["sudo nixos-rebuild switch --rollback"] }
    ]
  },
  {
    name: "UPDATING",
    items: [
      { title: "UPDATE ALL (THEN REBUILD)", lines: [flake, "nix flake update"] },
      { title: "UPDATE ONE INPUT", lines: [flake, "nix flake update nixpkgs"] },
      { title: "WHAT AN UPDATE CHANGED", lines: [flake, "git diff --stat flake.lock", "nix flake metadata"] },
      { title: "UNDO AN UPDATE", lines: [flake, "git checkout flake.lock"] },
      { title: "CHECK THE FLAKE FOR MISTAKES", lines: [flake, "git add -A", "nix flake check"] }
    ]
  },
  {
    name: "LOOK THINGS UP",
    items: [
      { title: "SEARCH FOR A PACKAGE", lines: ["nix search nixpkgs firefox"] },
      { title: "RUN A PACKAGE ONCE", lines: ["nix run nixpkgs#cowsay -- hello"] },
      { title: "A SHELL WITH A PACKAGE", lines: ["nix shell nixpkgs#ripgrep nixpkgs#jq"] },
      { title: "READ ONE OPTION OF THIS CONFIG", lines: [flake, "nix eval .#nixosConfigurations.nixos.config.networking.hostName"] },
      { title: "TRY NIX CODE", lines: [flake, "nix repl", ":lf .", "nixosConfigurations.nixos.config.users.users.frozen.extraGroups"] },
      { title: "EVERYTHING INSTALLED SYSTEM WIDE", lines: ["nix-store -q --references /run/current-system/sw | sed 's|/nix/store/[^-]*-||' | sort"] }
    ]
  },
  {
    name: "CLEAN UP",
    items: [
      { title: "LIST THE SYSTEM GENERATIONS", lines: ["sudo nix-env --list-generations -p /nix/var/nix/profiles/system"] },
      { title: "DELETE OLD GENERATIONS (KEEPS 14 DAYS)", lines: ["sudo nix-collect-garbage --delete-older-than 14d", "cd ~/nixos-config", "sudo nixos-rebuild boot --flake .#nixos"] },
      { title: "DELETE EVERYTHING UNUSED", lines: ["sudo nix-collect-garbage -d"] },
      { title: "SHRINK THE STORE (HARD LINKS)", lines: ["sudo nix store optimise"] },
      { title: "HOW BIG IS THE STORE", lines: ["du -sh /nix/store", "nix path-info -Sh /run/current-system"] }
    ]
  },
  {
    name: "WHEN SOMETHING IS WRONG",
    items: [
      { title: "WHAT FAILED TO START", lines: ["systemctl --failed", "systemctl --user --failed"] },
      { title: "ERRORS SINCE BOOT", lines: ["journalctl -b -p err --no-pager | tail -50"] },
      { title: "LOG OF ONE SERVICE", lines: ["journalctl -b -u NetworkManager --no-pager | tail -50"] },
      { title: "RESTART THE SHELL", lines: ["qs kill; qs -d"] },
      { title: "SHELL ERRORS AND WARNINGS", lines: ["qs log | grep -iE \"error|warn|not a type\" | tail -30"] },
      { title: "RELOAD HYPRLAND'S CONFIG", lines: ["hyprctl reload", "hyprctl monitors | grep -E \"Monitor|at \""] }
    ]
  },
  {
    name: "APPLICATIONS",
    items: [
      {
        title: "ADD OR CHANGE AN APP (NAME, ICON, CATEGORY)",
        lines: [
          '# home/frozen/settings.nix, inside  apps = { ... };',
          '# the key is the desktop file name without .desktop. Every field is optional:',
          '"vesktop" = {',
          '  name = "Discord";             # title in the launcher, bar, dock and overview',
          '  icon = "discord";             # a name from the icon pack',
          '  comment = "Chat";             # launcher description (no ":" in it)',
          '  categories = [ "Network" "InstantMessaging" ];   # added to the app\'s own',
          '  classes = [ "vesktop" ];      # window classes, when they differ from the key',
          '  titleIcon = true;             # the bar shows the icon in full color',
          '  bypassVpn = true;             # start outside the VPN',
          '};'
        ]
      },
      { title: "FIND AN APP'S KEY", lines: ["ls /run/current-system/sw/share/applications /etc/profiles/per-user/$USER/share/applications", "flatpak list --columns=application"] },
      { title: "FIND AN ICON NAME", lines: ["# Studio window, ICONS tab: search, then click a name to copy it", 'icon = "name";'] },
      { title: "FIND A WINDOW'S CLASS (FOR classes)", lines: ["# run this, then click the app's window within 3 seconds", "sleep 3; hyprctl activewindow | grep class"] },
      { title: "CATEGORIES YOU CAN USE", lines: ["Network InstantMessaging Graphics Game Steam AudioVideo Development Office System Utility"] },
      {
        title: "A MENU ENTRY FOR A PROGRAM THAT HAS NONE",
        lines: [
          '# home/frozen/apps/entries.nix',
          '"btop" = {',
          '  name = "Btop";',
          '  exec = "kitty --title btop btop";',
          '  icon = "utilities-system-monitor";',
          '  categories = [ "System" "Monitor" ];',
          '};'
        ]
      },
      { title: "HIDE AN APP FROM THE MENU", lines: ['# home/frozen/apps/entries.nix', '"org.kde.kate".hide = true;'] },
      { title: "APPLY (THEN LOG OUT AND IN ONCE)", lines: [flake, "git add -A", "sudo nixos-rebuild switch --flake .#nixos"] }
    ]
  },
  {
    name: "GITHUB",
    items: [
      { title: "FIRST TIME", lines: ["nix shell nixpkgs#gh", "gh auth login", "gh auth setup-git", flake, "gh repo create nixos-config --private --source=. --push"] },
      { title: "EACH TIME", lines: [flake, "git add -A", "git commit -m \"what changed\"", "git push"] },
      { title: "WHAT CHANGED SINCE THE LAST COMMIT", lines: [flake, "git status --short", "git diff --stat"] }
    ]
  },
  {
    name: "SHARE THE CONFIG",
    items: [
      { title: "TREE", lines: ["nix run nixpkgs#tree -- -a -I .git ~/nixos-config"] },
      { title: "EXPORT EVERYTHING TO ONE TXT", lines: exportLines }
    ]
  }
];
