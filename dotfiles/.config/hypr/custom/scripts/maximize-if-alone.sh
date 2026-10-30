#!/usr/bin/env bash
# Maximize window $1 only if it is the sole tiled window on its workspace.
# Checked after a short delay, once the window is actually in the layout
# (the count seen at window.open time is not reliable).
addr="$1"
sleep 0.1
clients=$(hyprctl clients -j) || exit 0
ws=$(jq -r --arg a "$addr" '.[] | select(.address == $a) | .workspace.id' <<<"$clients")
[ -n "$ws" ] || exit 0
n=$(jq --argjson ws "$ws" '[.[] | select(.workspace.id == $ws and .mapped and (.hidden | not) and (.floating | not))] | length' <<<"$clients")
[ "$n" -eq 1 ] || exit 0
hyprctl dispatch "hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\", window = \"address:$addr\" })"
