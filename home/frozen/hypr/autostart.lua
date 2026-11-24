----------------------------------------------------------------------
-- Autostart
----------------------------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- hyprpolkitagent")
    hl.exec_cmd("uwsm app -- env QS_ICON_THEME=Gruvbox-Plus-Dark quickshell")

    -- Clipboard history for the quick window: remember everything that gets copied
    hl.exec_cmd("uwsm app -- " .. tools.wl_paste .. " --type text --watch " .. tools.cliphist .. " store")
    hl.exec_cmd("uwsm app -- " .. tools.wl_paste .. " --type image --watch " .. tools.cliphist .. " store")
end)
