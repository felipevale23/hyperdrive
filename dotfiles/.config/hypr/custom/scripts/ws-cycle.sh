#!/usr/bin/env bash
# Cycle workspace focus through only the workspaces that have windows
# (plus the current one), wrapping around. Arg: "next" (default) or "prev".
#
# hyprctl's plain `dispatch workspace <id>` is rejected under Hyprland's Lua
# config parser, so we dispatch via the Lua form.
set -euo pipefail

dir="${1:-next}"

cur="$(hyprctl activeworkspace -j | jq -r '.id')"

# Non-empty workspaces + the current one, unique, numerically sorted.
mapfile -t ids < <(
    { hyprctl workspaces -j | jq -r '.[] | select(.windows > 0) | .id'; echo "$cur"; } \
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

hyprctl dispatch "hl.dsp.focus({workspace=\"${ids[$next]}\"})"
