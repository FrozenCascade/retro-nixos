-- Hardware keys: media keys, extra screenshot/recording keys and the power button.
-- Nix puts a `tools` table in front of this file (home/frozen/keys.nix), so no path depends on PATH.
-- Screenshots and recording belong to the Studio (see studio.lua); the keys here only call its IPC.
--
-- Keys are bound by the name they send, not by their F-number: the laptop and the external keyboard put
-- different icons on different F-keys, but the names are the same. To see what a key sends:
--   nix shell nixpkgs#wev -c wev

local mod = "SUPER"

----------------------------------------------------------------------
-- Media keys (the laptop's Fn row and the external keyboard's media layer)
----------------------------------------------------------------------
-- { key name, command, repeats while held }
-- Brightness goes through the shell (every monitor, with the OSD), not brightnessctl.
local media = {
    { "XF86MonBrightnessDown", "qs ipc call display down",                                  true  },
    { "XF86MonBrightnessUp",   "qs ipc call display up",                                    true  },
    { "XF86AudioMute",         tools.wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle",       false },
    { "XF86AudioLowerVolume",  tools.wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-",        true  },
    { "XF86AudioRaiseVolume",  tools.wpctl .. " set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",   true  },
    { "XF86AudioMicMute",      tools.wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle",     false },
    { "XF86RFKill",            tools.rfkill .. " toggle all",                                false },
    { "XF86AudioPlay",         tools.playerctl .. " play-pause",                             false },
    { "XF86AudioNext",         tools.playerctl .. " next",                                   false },
    { "XF86AudioPrev",         tools.playerctl .. " previous",                               false },
}

for _, k in ipairs(media) do
    -- locked: also works on the lock screen
    hl.bind(k[1], hl.dsp.exec_cmd(k[2]), { locked = true, repeating = k[3] })
end

----------------------------------------------------------------------
-- Studio shortcuts (Print and Super+F10 are in studio.lua)
----------------------------------------------------------------------
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("qs ipc call studio shot region"))   -- the external keyboard's screenshot key
hl.bind("XF86Launch8",         hl.dsp.exec_cmd("qs ipc call studio record toggle")) -- the HP key on the laptop's F12
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("qs ipc call studio record toggle"))

----------------------------------------------------------------------
-- Function keys: shell windows and mic mute
----------------------------------------------------------------------
-- The external keyboard's F3-F6 and the laptop's Fn+F-keys send plain F-keys, so these also replace
-- those keys in apps (F5 no longer reloads a page; Ctrl+R still does). Delete a line to give the key back.
local function popup(name) return hl.dsp.exec_cmd("qs ipc call bar toggle " .. name) end

hl.bind("F1", hl.dsp.exec_cmd("qs ipc call display down"), { repeating = true })  -- external F1: brightness down
hl.bind("F2", hl.dsp.exec_cmd("qs ipc call display up"),   { repeating = true })  -- external F2: brightness up
hl.bind("F3", popup("status"))     -- external F3: the system window
hl.bind("F4", popup("ai"))         -- the AI window
hl.bind("F5", hl.dsp.exec_cmd(tools.wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))  -- mic mute
hl.bind("F6", popup("overview"))   -- the overview

----------------------------------------------------------------------
-- Power button: lock the screen (a tap never powers off, see modules/system/power.nix)
----------------------------------------------------------------------
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("qs ipc call lock lock"))
