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
