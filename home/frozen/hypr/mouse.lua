----------------------------------------------------------------------
-- Mouse
----------------------------------------------------------------------
-- Super + left drag = move, Super + right drag = resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Super + double left click = toggle fullscreen (second click within 300 ms)
local click_pending = false
hl.bind(mod .. " + mouse:272", function()
    if click_pending then
        click_pending = false
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    else
        click_pending = true
        hl.timer(function() click_pending = false end, { timeout = 300, type = "oneshot" })
    end
end, { click = true })
