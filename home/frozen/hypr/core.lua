-- NOTE: home/frozen/hyprland.nix joins the files in this folder into one hyprland.lua, in the order
-- listed there. Nix puts these generated tables in front of everything:
--   theme        -> Stylix palette, theme.base00 ... theme.base0F ("rrggbb")
--   settings     -> monitors, workspace count and keyboard layouts, shared with Quickshell
--                   (home/frozen/settings.nix)
--   tools        -> exact paths of cliphist and wl-paste
--   plugin_paths -> plugin .so paths, plugin_paths.dynamic_cursors
--   app_rules    -> window rules for applications (home/frozen/apps/entries.nix)
--
-- All files share one scope, so the locals below are visible in every file that comes after this one.

----------------------------------------------------------------------
-- Constants and helpers
----------------------------------------------------------------------
local mod       = "SUPER"
local EXTERNAL  = settings.external_monitor   -- numbered workspaces 1..WS_COUNT live here
local LAPTOP    = settings.laptop_monitor     -- the single laptop workspace lives here
local LAPTOP_WS = settings.laptop_workspace   -- its name (key: `)
local WS_COUNT  = settings.workspace_count    -- numbered workspaces on the external monitor

-- "rrggbb" + optional alpha -> rgba(...) string
local function rgba(hex, alpha) return "rgba(" .. hex .. (alpha or "ff") .. ")" end

-- A workspace name -> the selector hyprland expects ("3" stays "3", "laptop" -> "name:laptop")
local function ws_selector(name)
    if tonumber(name) then return name end
    return "name:" .. name
end
