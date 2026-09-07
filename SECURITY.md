# Security notes

This repo is public. Before every push, run:

```sh
git diff --cached | grep -nEi 'ghp_|github_pat_|AIza|sk-|-----BEGIN|xox[baprs]-|AKIA|ocid1\.(tenancy|user)|password=|_TOKEN='
```

## What is deliberately **not** here

| Kept out | Where it belongs |
|---|---|
| GitHub / Gemini / deploy tokens | `~/.zshrc_secrets` (chmod 600, git-ignored). Template: `dotfiles/.zshrc_secrets.example` |
| Oracle Cloud tenancy OCID + region | same — commented placeholder only in `.zshrc_custom` |
| SSH keys, `~/.ssh/config`, `known_hosts` | never packaged |
| `~/.oci`, `~/.aws`, `~/.azure`, `~/.gnupg` | never packaged |
| `~/.claude*`, shell history, `machine-id` | never packaged |
| Hostname, real user password | set by the installer at install time; the live user is passwordless with autologin, root is locked |

## Live ISO

- No default password ships in the image. `scripts/build.sh` does **not** bake
  a `/etc/shadow` with a hash; autologin for the live user, `passwd -l root`.
- The `[hyperdrive]` pacman repo (once enabled) uses `SigLevel = Optional TrustAll`
  only for a repo **you** publish from CI — sign it (`repo-add -s`, `SigLevel = Required`)
  before recommending the ISO to anyone else.

## Personalisation (not secrets, but yours)

- `dotfiles/.zshrc_custom` — `$HOME/dev/sh/shell-scripts` PATH + `connect`/`sendFile`/…
  aliases point at a private repo; harmless if absent.
- `dotfiles/.config/hypr/custom/general.lua` — hard-codes the mouse device name
  `cooler-master-cm110-gaming-mouse`; adjust for your hardware.
- `dotfiles/.config/kitty/kitty.conf` — `include` path to the quickshell-generated
  theme; provided by end-4.

## Reporting

Open a private security advisory on GitHub rather than a public issue.
