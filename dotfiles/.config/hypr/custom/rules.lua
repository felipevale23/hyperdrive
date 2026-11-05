-- Antigravity window rules
hl.window_rule({ match = { class = "^(Antigravity|antigravity)$" }, tile = true })

-- LibreOffice: open as a floating, centered window instead of filling the tile
hl.window_rule({ match = { class = "^(libreoffice-.*)$" }, float = true })
hl.window_rule({ match = { class = "^(libreoffice-.*)$" }, center = true })
hl.window_rule({ match = { class = "^(libreoffice-.*)$" }, size = {"(monitor_w*0.72)", "(monitor_h*0.82)"} })

-- Maximized windows lose their hyprbars title bar; hover the window title in
-- the Quickshell top bar for its min/max/close buttons (bar/WindowControls.qml).
hl.window_rule({ match = { fullscreen_state_internal = 1 }, ["hyprbars:no_bar"] = true })

-- An app opened on an empty workspace starts maximized (so without its hyprbars
-- title bar). Opening a second one un-maximizes it (misc.on_focus_under_fullscreen
-- = 2) and they tile side by side, title bars back.
hl.on("window.open", function(w)
    if w.floating or w.fullscreen ~= 0 or not w.workspace or w.workspace.windows ~= 1 then
        return
    end
    -- Deferred: dispatched straight from the event, the window isn't in the
    -- layout yet and the maximize is lost (or lands on another window). The
    -- script re-checks the window count then, since the one seen here can be stale.
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/custom/scripts/maximize-if-alone.sh " .. w.address)
end)
