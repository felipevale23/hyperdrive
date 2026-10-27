-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Keyboard layout: Brazilian ABNT2
hl.config({
    input = {
        kb_layout = "br",
        kb_variant = "abnt2",
    }
})

-- Lower mouse sensitivity (range -1.0 .. 1.0, 0 = libinput default).
-- Per-device so the laptop touchpad is unaffected. Rename for your mouse.
hl.device({
    name        = "cooler-master-cm110-gaming-mouse",
    sensitivity = -0.8,
})

-- Dwindle tiling: split a tile side-by-side only while it's wider than 1.5x its
-- height, otherwise stack top/bottom. On a wide/ultrawide monitor the first two
-- windows become columns and a third one stacks inside a column instead of
-- making a cramped third column. Raise toward ~2.4 to stack even the first split.
hl.config({
    dwindle = {
        split_width_multiplier = 1.5,
        force_split = 2,   -- new window always takes the right/bottom side
    }
})

-- Plasma-style title bars (hyprbars plugin): title on the left,
-- minimize / maximize / close on the right. The plugin .so is loaded in
-- custom/execs.lua; hl.plugin.hyprbars is nil until then (Hyprland re-parses
-- this file once the plugin loads), hence the guard.
hl.config({
    plugin = {
        hyprbars = {
            bar_height              = 28,
            bar_color               = "rgba(282A36FF)",
            bar_text_font           = "JetBrainsMono Nerd Font",
            bar_text_size           = 11,
            bar_text_align          = "left",
            bar_padding             = 12,
            bar_button_padding      = 8,
            bar_buttons_alignment   = "right",
            bar_part_of_window      = true,
            bar_precedence_over_border = true,
            on_double_click         = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'",
        },
    },
})

if hl.plugin and hl.plugin.hyprbars then
    -- Buttons are laid out right-to-left: first added = rightmost.
    hl.plugin.hyprbars.add_button({
        bg_color = "rgba(FF5555FF)", fg_color = "rgba(282A36FF)", size = 16, icon = "",
        action = "hyprctl dispatch 'hl.dsp.window.close()'",
    })
    hl.plugin.hyprbars.add_button({
        bg_color = "rgba(44475AFF)", fg_color = "rgba(F8F8F2FF)", size = 16, icon = "",
        action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })'",
    })
    -- Hyprland has no real minimize: send the window to the scratchpad
    -- (SUPER+S brings it back).
    hl.plugin.hyprbars.add_button({
        bg_color = "rgba(44475AFF)", fg_color = "rgba(F8F8F2FF)", size = 16, icon = "",
        action = "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:special\", follow = false })'",
    })
end
