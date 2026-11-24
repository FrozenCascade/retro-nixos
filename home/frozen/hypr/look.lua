----------------------------------------------------------------------
-- Look: no gaps, Stylix-colored borders
----------------------------------------------------------------------
hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 2,
        col = {
            active_border = {
                colors = { rgba(theme.base07), rgba(theme.base05) },
                angle  = 45,
            },
            inactive_border = rgba(theme.base02, "aa"),
        },
    },
})
