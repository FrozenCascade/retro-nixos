----------------------------------------------------------------------
-- Workspaces
----------------------------------------------------------------------
-- Laptop screen: one workspace, on `
hl.workspace_rule({ workspace = "name:" .. LAPTOP_WS, monitor = LAPTOP, default = true, persistent = true })
hl.bind(mod .. " + grave",         hl.dsp.focus({ workspace = "name:" .. LAPTOP_WS }))
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "name:" .. LAPTOP_WS }))

-- External monitor: 1..WS_COUNT
for i = 1, WS_COUNT do
    hl.workspace_rule({ workspace = tostring(i), monitor = EXTERNAL, default = (i == 1) })
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Super + scroll: step through 1..WS_COUNT and wrap (up = next, down = previous).
-- Does nothing on the laptop workspace or inside a hidden workspace.
local function step_workspace(delta)
    local ws = hl.get_active_workspace()
    if ws == nil or ws.special or ws.id < 1 or ws.id > WS_COUNT then
        return
    end
    local target = ((ws.id - 1 + delta) % WS_COUNT) + 1
    hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
end

hl.bind(mod .. " + mouse_down", function() step_workspace(-1) end)
hl.bind(mod .. " + mouse_up",   function() step_workspace(1)  end)
