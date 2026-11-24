----------------------------------------------------------------------
-- Window rules for the Quickshell windows (launcher, popups, tool windows)
----------------------------------------------------------------------
-- Floating, pinned, no border, no shadow (the QML draws its own).
-- Sizes below are the FRAME sizes from the QML files; the 4 px shadow is added here.
local SHADOW = 4
local EDGE   = 10    -- gap to the side of the screen
local TOP    = 44    -- clears the top bar
local DOCK   = 112   -- the launcher sits this far above the bottom edge

-- where a window opens (Hyprland expressions, evaluated per monitor)
local at = {
    left   = { tostring(EDGE), tostring(TOP) },
    right  = { "monitor_w - window_w - " .. EDGE, tostring(TOP) },
    center = { "(monitor_w - window_w) / 2", tostring(TOP) },
    dock   = { "(monitor_w - window_w) / 2", "monitor_h - window_h - " .. DOCK },
}

-- name:  the window title the QML sets ("qs-quick"); matched exactly unless `title` is given
-- w, h:  the frame size from the QML
local function shell_window(name, w, h, pos, title)
    hl.window_rule({
        name        = name,
        match       = { title = title or ("^" .. name .. "$") },
        float       = true,
        pin         = true,
        size        = { tostring(w + SHADOW), tostring(h + SHADOW) },
        move        = pos,
        border_size = 0,
        no_shadow   = true,
    })
end

--                 name             w     h    where
shell_window("qs-launcher",     640,  520, at.dock)     -- Launcher.qml
shell_window("qs-quick",        600,  600, at.left)     -- QuickPopup.qml
shell_window("qs-weather",      560,  720, at.left)     -- WeatherPopup.qml
shell_window("qs-overview",    1520,  372, at.center)   -- OverviewPopup.qml (short: keeps the launcher uncovered)
shell_window("qs-calendar",     480,  720, at.right)    -- CalendarPopup.qml
shell_window("qs-ai",           520,  740, at.right)    -- ai-browser/main.qml

-- Tool windows (audio, session ...) share one rule; the wider Session window comes after it
-- so it wins. To add a tool, nothing is needed here unless it is a different size.
shell_window("qs-tool",         440,  640, at.right, "^qs-tool-.*$")
shell_window("qs-tool-studio",  640,  640, at.right)
