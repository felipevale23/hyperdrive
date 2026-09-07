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
-- Per-device so the laptop touchpad is unaffected.
hl.device({
    name        = "cooler-master-cm110-gaming-mouse",
    sensitivity = -0.8,
})
