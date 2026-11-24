----------------------------------------------------------------------
-- Input: keyboard layouts, click to focus, never warp the cursor
----------------------------------------------------------------------
hl.config({
    input = {
        follow_mouse = 2,
        float_switch_override_focus = 0,

        -- The layouts are listed in home/frozen/settings.nix (keyboardLayouts)
        kb_layout  = settings.kb_layout,
        kb_variant = settings.kb_variant,

        -- Right Ctrl = Compose
        -- Layout switching is handled by the Super+' binding in binds.lua
        kb_options = "compose:rctrl",
    },
    cursor = {
        no_warps = true,
    },
})
