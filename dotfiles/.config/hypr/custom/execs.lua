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

hl.on("hyprland.start", function ()
    -- Title bars with min/max/close buttons (hyprbars, AUR hyprland-plugin-hyprbars;
    -- falls back to a hyprpm build). Config in custom/general.lua.
    autostart([[sh -c 'p=/usr/lib/libhyprbars.so; [ -f "$p" ] || p="/var/cache/hyprpm/$USER/hyprland-plugins/hyprbars.so"; hyprctl plugin load "$p"']])

    -- Global app menu in the top bar: Qt/KDE apps only export their menu bar
    -- over DBus when an AppMenu registrar exists (~/.local/bin/appmenu).
    autostart("$HOME/.local/bin/appmenu registrar")
end)

-- Dracula purple cursor. end-4's startup sets its own, so apply this after it.
hl.on("hyprland.start", function ()
    hl.exec_cmd("sh -c 'sleep 3; hyprctl setcursor Bibata-Modern-Dracula 24'")
end)
