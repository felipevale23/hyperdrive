#!/usr/bin/env bash
# Cycle workspace focus through only the regular workspaces that have windows
# (plus the current one), wrapping around. Arg: "next" (default) or "prev".
#
# Runs as a plain command (from keybinds.lua via exec_cmd), so the classic
# `hyprctl dispatch workspace <id>` IPC call is what we want here — the Lua
# config format only affects hyprland.conf parsing, not the IPC socket.
set -euo pipefail

dir="${1:-next}"

cur="$(hyprctl activeworkspace -j | jq -r '.id')"

# Non-empty regular workspaces (id > 0 excludes special/scratchpad) + the
# current one, unique, numerically sorted.
mapfile -t ids < <(
    { hyprctl workspaces -j | jq -r '.[] | select(.windows > 0 and .id > 0) | .id'; echo "$cur"; } \
        | sort -n -u
)

n=${#ids[@]}
(( n <= 1 )) && exit 0

# Index of the current workspace in the list.
idx=0
for i in "${!ids[@]}"; do
    [[ "${ids[$i]}" == "$cur" ]] && idx=$i && break
done

if [[ "$dir" == "prev" ]]; then
    next=$(( (idx - 1 + n) % n ))
else
    next=$(( (idx + 1) % n ))
fi

hyprctl dispatch workspace "${ids[$next]}"
