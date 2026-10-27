-- Antigravity window rules
hl.window_rule({ match = { class = "^(Antigravity|antigravity)$" }, tile = true })

-- Maximized windows lose their hyprbars title bar; hover the window title in
-- the Quickshell top bar for its min/max/close buttons (bar/WindowControls.qml).
hl.window_rule({ match = { fullscreen_state_internal = 1 }, ["hyprbars:no_bar"] = true })
