----------------------------------------------------------------------
-- Studio (screenshots, recording, autoclicker; the window is in Quickshell: components/bar/studio)
----------------------------------------------------------------------
-- A screenshot goes to the clipboard; the notification offers SAVE and ANNOTATE.
hl.bind("Print",                hl.dsp.exec_cmd("qs ipc call studio shot region"))
hl.bind("SHIFT + Print",        hl.dsp.exec_cmd("qs ipc call studio shot screen"))
hl.bind(mod .. " + Print",      hl.dsp.exec_cmd("qs ipc call studio shot window"))

-- Super+F10: recording start/stop.
hl.bind(mod .. " + F10",        hl.dsp.exec_cmd("qs ipc call studio record toggle"))

-- The mouse side buttons (4 = back, 5 = forward). Non-consuming: the window under the pointer still gets
-- them. What they do (if anything) is chosen in the Studio window, RECORD tab. Wrapped so a different
-- bind option name in a newer Hyprland cannot stop the rest of the config from loading.
local ok, err = pcall(function()
    hl.bind("mouse:275", hl.dsp.exec_cmd("qs ipc call studio side 4"), { non_consuming = true })
    hl.bind("mouse:276", hl.dsp.exec_cmd("qs ipc call studio side 5"), { non_consuming = true })
end)
if not ok then print("studio.lua: side buttons not bound: " .. tostring(err)) end


-- The recording preview (mpv, started by the PREVIEW button in the RECORD tab).
hl.window_rule({
    name = "studio-preview", match = { title = "^qs-preview$" },
    float = true, size = { "960", "540" },
})
