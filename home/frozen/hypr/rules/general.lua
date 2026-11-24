----------------------------------------------------------------------
-- Window rules that apply to everything
----------------------------------------------------------------------
-- No border when there is only one visible tiled window
hl.window_rule({
    name  = "no-border-single-tile",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
})
