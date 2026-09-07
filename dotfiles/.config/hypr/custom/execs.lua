-- Extra autostart. Loaded from custom/ so it survives dots-hyprland updates.
-- end-4 runs these on the hyprland.start event.

local function autostart(cmd)
    if type(hl.exec_cmd) == "function" then
        hl.exec_cmd(cmd)
    elseif type(hl.exec) == "function" then
        hl.exec(cmd)
    elseif hl.dsp and type(hl.dsp.exec_cmd) == "function" then
        hl.dispatch(hl.dsp.exec_cmd(cmd))
    end
end

-- KDE Connect daemon (phone integration; tray icon appears once it's up)
autostart("/usr/lib/kdeconnectd")
