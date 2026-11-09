#!/usr/bin/env bash
# Restore minimized windows. Minimize moves a window to special:special
# (the scratchpad); this moves every window there back to the current
# workspace at full size and focuses the last one.
#
# hyprctl's plain dispatchers are rejected under Hyprland's Lua config
# parser, so we dispatch via the Lua form.
set -euo pipefail

ws="$(hyprctl activeworkspace -j | jq -r '.id')"
# Lock screen and other temporary workspaces have ids outside 1..100
(( ws >= 1 && ws <= 100 )) || exit 0

mapfile -t addrs < <(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:special") | .address')
(( ${#addrs[@]} > 0 )) || exit 0

# Hide the scratchpad if it is open, so it doesn't stay up empty or cover the windows
if [[ "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')" == "special:special" ]]; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("special")' >/dev/null
fi

for a in "${addrs[@]}"; do
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ws\", follow = false, window = \"address:$a\" })"
done
hyprctl dispatch "hl.dsp.focus({ window = \"address:${addrs[-1]}\" })" >/dev/null
