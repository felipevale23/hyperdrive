hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd("antigravity"), { description = "App: Launch Google Antigravity" })

-- ── Windows-style Alt+Tab workspace switcher ──────────────────────────────
-- 1st Alt+Tab  -> flip to the previous workspace, no overview.
-- Keep Alt held, tap Tab again -> overview picker opens, cycle active workspaces.
-- Release Alt (or Escape) -> overview closes, sequence ends. SHIFT reverses.
-- A submap is used so the Alt-release bind fires reliably after Tab was pressed.
local wsCycle   = "$HOME/.config/hypr/custom/scripts/ws-cycle.sh"
-- single-instance is handled by the script's own lockfile
local altWatch  = "setsid -f $HOME/.config/hypr/custom/scripts/alt-release-watch.py"

local function altTabCycle(dir)
    return function()
        hl.dispatch(hl.dsp.global("quickshell:overviewWorkspacesOpen"))
        hl.dispatch(hl.dsp.exec_cmd(wsCycle .. " " .. dir))
    end
end
local function altTabEnd()
    hl.dispatch(hl.dsp.global("quickshell:overviewWorkspacesClose"))
    hl.dispatch(hl.dsp.submap("reset"))
end
local function noop() end

-- First press: flip to previous workspace (no overview), arm the submap, and
-- start the watcher that ends everything the moment Alt is physically released.
local function altTabStart()
    hl.dispatch(hl.dsp.focus({ workspace = "previous" }))
    hl.dispatch(hl.dsp.submap("alttab"))
    hl.dispatch(hl.dsp.exec_cmd(altWatch))
end
hl.bind("ALT + Tab",         altTabStart, { description = "Workspace: Alt-Tab switcher", repeating = false })
hl.bind("ALT + SHIFT + Tab", altTabStart, { repeating = false })

hl.define_submap("alttab", function()
    hl.bind("ALT + Tab",         altTabCycle("next"), { repeating = false })
    hl.bind("ALT + SHIFT + Tab", altTabCycle("prev"), { repeating = false })
    -- Alt release is handled by alt-release-watch.py (evdev). These are just
    -- manual escape hatches.
    hl.bind("Escape",   altTabEnd)
    hl.bind("Return",   altTabEnd)
    hl.bind("catchall", altTabEnd)
end)
