----------------------------------------------------------------------
-- Plugins (keep this file last in hyprland.nix: if a plugin errors, everything above is already registered)
----------------------------------------------------------------------
hl.plugin.load(plugin_paths.dynamic_cursors)

hl.config({
    plugin = {
        dynamic_cursors = {
            enabled = true,
            mode    = "none",        -- "none", "rotate", "tilt", "stretch"
            shake   = {
                enabled   = true,    -- shake the mouse to find the cursor
                threshold = 8.0,     -- lower = triggers more easily
            },
        },
    },
})
