----------------------------------------------------------------------
-- Hidden workspaces (every workspace has its own: special:hidden_<name>)
----------------------------------------------------------------------
-- Super + 0: show/hide the hidden windows of the current workspace
hl.bind(mod .. " + 0", function()
    local ws = hl.get_active_workspace()
    if ws == nil then return end

    local hidden = ws.name:match("(hidden_.+)$")
    if hidden then
        hl.dispatch(hl.dsp.workspace.toggle_special(hidden))
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("hidden_" .. ws.name))
    end
end)

-- Super + middle click: hide the focused window (focus stays put),
-- or, if it is already hidden, send it back to its workspace and follow it.
local function toggle_hidden_window()
    local w = hl.get_active_window()
    if w == nil then return end

    if w.workspace.special then
        local origin = w.workspace.name:match("hidden_(.+)$")
        hl.dispatch(hl.dsp.window.move({
            workspace = origin and ws_selector(origin) or "1",
            follow    = true,
        }))
    else
        hl.dispatch(hl.dsp.window.move({
            workspace = "special:hidden_" .. w.workspace.name,
            follow    = false,
        }))
    end
end

hl.bind(mod .. " + mouse:274", toggle_hidden_window)   -- Super + H does the same
