----------------------------------------------------------------------
-- Programs (the Super + letter shortcuts are in shortcuts.lua; Super+G maximizes, see below)
----------------------------------------------------------------------
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("uwsm app -- kitty"))
hl.bind(mod .. " + SPACE",  hl.dsp.exec_cmd("qs ipc call launcher toggle"))

-- Super+L: lock the screen (components/lock)
hl.bind(mod .. " + L", hl.dsp.exec_cmd("qs ipc call lock lock"))


----------------------------------------------------------------------
-- Windows
----------------------------------------------------------------------
hl.bind(mod .. " + Q",         hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + F",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + G",         hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mod .. " + V",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Arrow keys:  Super = focus,  Super+Shift = move,  Super+Ctrl = resize by 40px
local arrows = {
    left  = { x = -40, y =   0 },
    right = { x =  40, y =   0 },
    up    = { x =   0, y = -40 },
    down  = { x =   0, y =  40 },
}
for dir, delta in pairs(arrows) do
    hl.bind(mod .. " + " .. dir,            hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir,    hl.dsp.window.move({ direction = dir }))
    hl.bind(mod .. " + CTRL + " .. dir,     hl.dsp.window.resize({ x = delta.x, y = delta.y, relative = true }),
            { repeating = true })
end
