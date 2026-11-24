----------------------------------------------------------------------
-- Super + letter shortcuts: programs, shell windows, window and workspace actions
----------------------------------------------------------------------
-- Super + ...
--   programs    W browser   E files     R launcher   J Jellyfin   Y FreeTube  U Spotify   I Inkscape
--               S Steam     D Discord   K Krita      B Sober      N Minecraft Bedrock     M Prism
--   shell       O VPN       A AI        T system     Z overview   X notes     C clipboard P pin the top bar
--   windows     H hide      / pin       G maximize (binds.lua)   F float   V fullscreen   Q close
--   system      L lock      ; sleep     ' keyboard layout        , and . previous/next workspace
-- Everything is in one pcall: a key name or option that a newer Hyprland changes cannot stop the rest of
-- the config (the rules and autostart come after this file) from loading.
local ok, err = pcall(function()
    local function run(cmd)   return hl.dsp.exec_cmd(cmd) end
    local function app(cmd)   return run("uwsm app -- " .. cmd) end
    local function shell(cmd) return run("qs ipc call " .. cmd) end

    local function bind(key, dispatcher)
        hl.bind(mod .. " + " .. key, dispatcher)
    end

    -- programs (Flatpak apps by their Flathub ID, see modules/applications/flatpak.nix)
    bind("W", app("vivaldi"))
    bind("E", app("dolphin"))
    bind("R", app("fuzzel"))
    bind("Y", app("freetube"))
    bind("U", app("spotify"))
    bind("I", app("inkscape"))
    bind("S", app("steam"))
    bind("D", app("vpn-bypass vesktop"))         -- Discord, started outside the VPN (settings.nix: bypassVpn)
    bind("K", app("krita"))
    bind("B", app("flatpak run org.vinegarhq.Sober"))
    bind("N", app("flatpak run io.mrarm.mcpelauncher"))
    bind("M", app("flatpak run org.prismlauncher.PrismLauncher"))
    bind("J", app("jellyfin-desktop"))

    -- the shell (components/bar/BarIpc.qml and components/lock)
    bind("O",         shell("bar vpn"))
    bind("A",         shell("bar toggle ai"))
    bind("T",         shell("bar toggle status"))
    bind("Z",         shell("bar toggle overview"))
    bind("X",         shell("bar quick 0"))        -- quick window, notes tab
    bind("C",         shell("bar quick 1"))        -- quick window, clipboard tab
    bind("P",         shell("bar pin"))
    bind("L",         shell("lock lock"))
    bind("semicolon", shell("lock sleep"))         -- the lock comes up first, so waking shows the lock screen

    -- keyboard layout (the list is in settings.nix)
    bind("apostrophe", run("hyprctl switchxkblayout all next"))

    -- windows and workspaces
    bind("H",     toggle_hidden_window)             -- hidden.lua; Super + 0 shows what is hidden
    bind("slash", hl.dsp.window.pin({ action = "toggle" }))
    bind("comma",  function() step_workspace(-1) end)
    bind("period", function() step_workspace(1)  end)
end)
if not ok then print("shortcuts.lua: " .. tostring(err)) end
