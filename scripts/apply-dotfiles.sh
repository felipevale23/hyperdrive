#!/usr/bin/env bash
# Deploy the hyperdrive dotfiles into $HOME. Safe to re-run; backs up anything
# it would overwrite to ~/.hyperdrive-backup/<timestamp>/.
set -euo pipefail

SRC="${1:-/usr/local/share/hyperdrive/dotfiles}"
[[ -d "$SRC" ]] || SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dotfiles"

BACKUP="$HOME/.hyperdrive-backup/$(date +%Y%m%d-%H%M%S)"

while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/}"
    dst="$HOME/$rel"
    if [[ -e "$dst" && ! -L "$dst" ]] && ! cmp -s "$f" "$dst"; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$dst" "$BACKUP/$rel"
    fi
    install -Dm"$(stat -c '%a' "$f")" "$f" "$dst"
    echo "  $rel"
done < <(find "$SRC" -type f -print0)

# secrets file: seed from example only if missing
if [[ ! -e "$HOME/.zshrc_secrets" && -e "$HOME/.zshrc_secrets.example" ]]; then
    cp "$HOME/.zshrc_secrets.example" "$HOME/.zshrc_secrets"
    chmod 600 "$HOME/.zshrc_secrets"
fi

[[ -d "$BACKUP" ]] && echo ":: overwritten files backed up to $BACKUP"
echo ":: dotfiles applied. Reload: exec zsh ; hyprctl reload"
