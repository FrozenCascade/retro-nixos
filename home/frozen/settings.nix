# One place for the things the Hyprland config and the Quickshell config both need to agree on.
# Hyprland gets them as a `settings` table in its Lua config; Quickshell gets them as the
# `Settings` singleton. Change a value here, rebuild, and both follow.
# Only list what you change here. Every setting, with its default, is in settings.defaults.nix;
# anything missing from this file comes from there (settings-load.nix merges and checks them).
{
  externalMonitor = "HDMI-A-1";   # numbered workspaces 1..workspaceCount live here (and the top bar)
  laptopMonitor   = "eDP-1";      # the single laptop workspace lives here
  laptopWorkspace = "laptop";     # name of that workspace (key: `)
  workspaceCount  = 6;            # numbered workspaces on the external monitor

  # Keyboard layouts, in the order Hyprland cycles through them (Super+').
  #   code / variant: what goes into Hyprland's kb_layout / kb_variant (keep them the same as
  #                   services.xserver.xkb in modules/desktop/desktopbase.nix)
  #   short:          the label in the quick window
  #   name:           what Hyprland reports as the active keymap. Check with:
  #                   hyprctl devices -j | grep active_keymap
  keyboardLayouts = [
    { code = "us";         variant = "";   short = "US"; name = "English (US)"; }
    { code = "qalbagutic"; variant = "qa"; short = "QA"; name = "English with Qalbagutic on Right Alt"; }
  ];
    # Names shown for the numbered workspaces (the bar buttons, the switch popup, the overview), in order.
  # glyph: the character, reading: how it is read.
  workspaceNames = [
    { glyph = "一"; reading = "Yī"; }
    { glyph = "二"; reading = "Èr"; }
    { glyph = "三"; reading = "Sān"; }
    { glyph = "四"; reading = "Sì"; }
    { glyph = "五"; reading = "Wǔ"; }
    { glyph = "六"; reading = "Liù"; }
  ];


  # One table for how apps look and where they go. The key is the desktop file name without .desktop
  # (`ls /run/current-system/sw/share/applications`, or `flatpak list` for Flatpak apps). Every field is optional:
  #   name        the title shown in the launcher, bar, dock and overview
  #   icon        an icon from the icon pack (find names with the ICONS tab in Studio)
  #   comment     the launcher description (avoid ":" in it, the emoji search reacts to it)
  #   categories  launcher categories added to the app's own: Network, InstantMessaging, Graphics, Game, Steam,
  #               AudioVideo, Development, Office, System, Utility
  #   onlyCategories  true = the categories above replace the ones in the app's own entry (Steam only, say)
  #   bypassVpn   true = start the app outside the VPN (needs modules/system/vpn-bypass.nix)
  #   glyph       the one-colour character in the bar's title box (a Nerd Font character; without it the category picks one)
  #   titleIcon   true = the bar's title box shows the icon-pack icon in full color instead of a glyph
  #   classes     window classes that belong to this app, when they differ from the key
  #               (show one with: sleep 3; hyprctl activewindow | grep class)
  # Rebuild, then log out and in once.
  apps = let
    # Steam games from the external drive: one line each. The id is the number in the store link
    # (or in steamapps/appmanifest_<id>.acf). Each game's entry is steam-<id>.desktop in
    # ~/.local/share/applications; here it also gets the window class steam_app_<id>, the tag Steam only
    # and an icon in the bar's title box. An icon of "INSERT" means none chosen yet: Steam's own icon stays.
    # Optional per game: icon = "name from the icon pack";
    steamGames = [
    { id = 105600; name = "Terraria"; comment = "2D Sandbox Adventure"; }
    { id = 1150690; name = "OMORI"; comment = "Surreal Turn-Based RPG"; icon = "omori"; }
    { id = 1222670; name = "The Sims 4"; comment = "Life Simulation"; icon = "emeral"; }
    { id = 1671210; name = "DELTARUNE"; comment = "Episodic RPG from the Undertale Creator"; icon = "deltarune"; }
    { id = 1718870; name = "Spaceflight Simulator"; comment = "Build and Fly Rockets"; icon = "CosmicViewer"; }
    { id = 17390; name = "Spore"; comment = "Evolution and Civilization Simulator"; icon = "openoffice4-startcenter"; }
    { id = 1927740; name = "Monument Valley 2"; comment = "Optical Illusion Puzzle Game"; icon = "monumentvalley2"; }
    { id = 227300; name = "Euro Truck Simulator 2"; comment = "Truck Driving Across Europe"; }
    { id = 236850; name = "Europa Universalis IV"; comment = "Grand Strategy"; icon = "eureka"; }
    { id = 246620; name = "Plague Inc Evolved"; comment = "Pandemic Strategy"; icon = "plague"; }
    { id = 255710; name = "Cities Skylines"; comment = "City Builder"; }
    { id = 264710; name = "Subnautica"; comment = "Underwater Survival"; icon = "bluefish"; }
    { id = 281990; name = "Stellaris"; comment = "Space Grand Strategy"; icon = "lutris_sanctum-2"; }
    { id = 289070; name = "Civilization VI"; comment = "Turn-Based Strategy"; }
    { id = 367520; name = "Hollow Knight"; comment = "Metroidvania Adventure"; }
    { id = 391540; name = "Undertale"; comment = "The RPG Where Nobody Has to Die"; icon = "undertale"; }
    { id = 394360; name = "Hearts of Iron IV"; comment = "World War II Grand Strategy"; icon = "atanks"; }
    { id = 400; name = "Portal"; comment = "Puzzle Game with Portals"; }
    { id = 413150; name = "Stardew Valley"; comment = "Farming Simulation"; }
    { id = 504230; name = "Celeste"; comment = "Precision Platformer"; icon = "lutris_sakura-spirit"; }
    { id = 508440; name = "Totally Accurate Battle Simulator"; comment = "Silly Physics Battles"; icon = "org.turbowarp.TurboWarp"; }
    { id = 529340; name = "Victoria 3"; comment = "Economic and Political Strategy"; icon = "lutris_the-battle-for-wesnoth"; }
    { id = 620; name = "Portal 2"; comment = "Co-op Puzzle Game"; }
    { id = 70; name = "Half-Life"; comment = "First Person Shooter Classic"; }
    { id = 949230; name = "Cities Skylines II"; comment = "City Builder Sequel"; }
    ];

    steamApps = builtins.listToAttrs (map (g: {
      name = "steam-${toString g.id}";
      value = {
        name = g.name;
        comment = g.comment;
        icon = g.icon or "INSERT";
        categories = [ "Steam" ];
        onlyCategories = true;               # the Game tag from the entry itself goes, Steam only
        classes = [ "steam_app_${toString g.id}" ];
        titleIcon = true;
      };
    }) steamGames);
  in {
    "org.vinegarhq.Sober" = { icon = "sober2"; categories = [ "Game" ]; };
    "org.vinegarhq.Vinegar" = { name = "Sober Studio"; icon = "rstudio"; categories = [ "Game" ]; };
    "io.mrarm.mcpelauncher" = { icon = "curseforge"; comment = "Minecraft Bedrock Edition launcher"; categories = [ "Game" ]; classes = [ "io.mrarm.mcpelauncher-ui-qt" "mcpelauncher-client" ]; titleIcon = true; };
    "vesktop" = { name = "Discord"; icon = "discord"; categories = [ "Network" "InstantMessaging" ]; classes = [ "vesktop" ]; glyph = "󰙯"; bypassVpn = true; };
    "gprojector" = { icon = "kimagemapeditor"; categories = [ "Graphics" ]; titleIcon = true; classes = [ "gov-nasa-giss-projector-GProjector" ]; };
    "lution" = { classes = [ "Tk" ]; name = "Lution"; icon = "lution"; comment = "Sober Bootstrapper"; categories = [ "Game" ]; titleIcon = true; };
    "freetube" = { name = "FreeTube"; categories = [ "AudioVideo" "Network" ]; };
    "org.jellyfin.JellyfinDesktop" = { icon = "jellyfin"; name = "Jellyfin"; categories = [ "AudioVideo" "Network" ]; };
    "spotify" = { name = "Spotify"; categories = [ "AudioVideo" ]; };
    "SpaceEngine" = { classes = [ "steam_app_314650" ]; name = "Space Engine"; icon = "spaceengine"; comment = "Photorealistic interactive 3D planetarium"; categories = [ "Steam" ]; onlyCategories = true; titleIcon = true; };
    "Universe Sandbox" = { classes = [ "steam_app_230290" ]; name = "Universe Sandbox"; icon = "kspaceduel"; comment = "Gravity and Space Simulator"; categories = [ "Steam" ]; onlyCategories = true; titleIcon = false; };
    "input-remapper-gtk" = { name = "Input Remapper"; icon = "coolercontrol"; comment = "Remap mouse buttons, keyboards and controllers"; categories = [ "Utility" ]; };
    "input-remapper-autoload" = { name = "Input Remapper Autoload"; icon = "coolercontrol"; comment = "Apply the saved Input Remapper presets"; categories = [ "System" ]; };
  } // steamApps;
}
