# Plan: OpenCode as the engine of the AI tab

Written 2026-11-04. Start here in a fresh session. Check every fact below against the
live system before relying on it, since versions and files change.

## Goal

Keep the Quickshell AI tab (left sidebar) as the interface and use OpenCode as the engine
behind it. The user wants their own UI with OpenCode's features: sessions, tools, file
edits, diffs and undo. Existing direct models (NVIDIA, Gemini) must keep working.

## Decisions already made

- Build in stages, each usable on its own, on branch `opencode-ai-tab` in `~/dev/sh/hyperdrive`, not `main`.
- OpenCode runs **on demand** only. No service that starts at login: the user chose this,
  and auto mode blocked one anyway.
- Bind to localhost only. Keys come from the keyring, never from files.
- Every tool waits for an Allow in the tab, except plain reads inside the project. `/tool none` turns tools off.
- `SUPER + A` opens the stock left sidebar again (changed by the user 2026-11-04, ahead of stage 2).
- Start folder is `~/.agents`, not `~/dev`, which holds important files, and not the home folder, which holds Drive,
  OneDrive and secrets (changed by the user 2026-11-05).
- The live config sets `"permission": {"*": "ask"}`, so the panel prompts too (decided 2026-11-04, after stage 0 found it allowed nearly everything).
- Stage 2 allows file reads inside the project without a prompt, and asks for everything else, including `.env` files
  and anything outside the project (decided 2026-11-04). This narrows "nothing runs without an Allow" for reads only.

## Current state

| Piece | Where | Notes |
|---|---|---|
| OpenCode 2.0.24 | package `opencode`, repo `extra`, MIT | v2 has no `web` command |
| Config | `~/.config/opencode/opencode.json` | NVIDIA provider, `{env:NVIDIA_API_KEY}`, default Mistral Large 4 |
| Launcher | `~/.local/bin/opencode-app` | exports keys, `opencode pair`, Chrome `--app`, stops service on close |
| Tab helper | `~/.local/bin/opencode-tab` | private server, sends messages, answers permissions, diff, undo, history |
| Rules and key | `~/.config/hypr/custom/rules.lua`, `custom/keybinds.lua` | merged by section in the repo copies, which differ from live |
| AI tab | `~/.config/quickshell/ii/modules/ii/sidebarLeft/`, `services/Ai.qml` | in patch 0013 |
| Provider code | `services/ai/*ApiStrategy.qml` | one strategy per API format |
| Patches | `patches/quickshell/0001`-`0013` | applied in order on `END4_REF` |

Keys: `secret-tool lookup application illogical-impulse`, JSON at `.apiKeys`. Never print them.

## OpenCode API facts (v2.0.24)

Spec: `GET /openapi.json` on a running server, 117 paths. Save it and read it; don't guess bodies.

Tested examples, event formats and permission behaviour are in `opencode-api-stage0.md`.

- Server: `opencode serve --hostname 127.0.0.1 --port 0`, which picks a free port and prints it.
  Password via `OPENCODE_SERVER_PASSWORD`, sent as Basic auth with user `opencode`.
- CLI calls that need a server, such as `session list`, auto-start `opencode serve --service` on port 49374. Check for strays.
- `/api/*` and `/openapi.json` return 401 without auth. Other paths such as `/session` are web app HTML, not data.
- Sessions: `GET,POST /api/session`, `GET,PATCH,DELETE /api/session/{id}`.
- Send: `POST /api/session/{id}/prompt` (`text`, `files`, `agents`, ...).
- Messages: `GET /api/session/{id}/message`, `.../message/{messageID}`.
- Live updates: `GET /api/event`, SSE `data:` lines for the whole server. Filter by `data.sessionID`.
- Model: `POST /api/session/{id}/model`, plus `GET /api/model`, `/api/model/default`, `/api/provider`.
- Stop: `POST /api/session/{id}/interrupt`.
- Permissions: `GET /api/permission/request`, `GET,POST /api/session/{id}/permission`,
  `POST /api/session/{id}/permission/{requestID}/reply` with `decision` `once`, `always` or `reject`.
  The shell action is named `shell`, not `bash`.
- Session `permissions` rules override the config. Without them the normal config allows nearly everything.
- Diff and undo: `GET /api/session/{id}/diff`, `POST .../revert/stage`, `.../revert/commit`, `DELETE .../revert`.
- Pairing: `POST /api/pair`, `GET /auth/connect/{code}`. Links are one-time, 5 minutes.
- Paths under `/api/experimental` may change. Avoid them.

## NVIDIA models tested with this key (2026-11-04)

Mistral Large 4 (`build` agent) and Nemotron 3 Ultra (`plan` agent) make tool calls. Nemotron 3.5
Super VL reads images and makes tool calls. FLUX.1-dev makes images at 1024x1024 through
`ai.api.nvidia.com/v1/genai` (`nvidia-ai image`). Nemotron Parse 2.0 returned 500/502, so
`nvidia-ai parse` uses Super VL. No video generation model was reachable (Cosmos routes 404).

## Stages

### Stage 0: prove the API from the command line
No UI work. With curl against a temporary server: create a session, send a prompt, read
`/api/event` while it replies, switch model, interrupt. Trigger a tool call and watch how
a permission request appears and how to reply. Record real payloads in `docs/plans/`.
Decide how the tab authenticates: its own `opencode serve` with a per-launch password looks
simplest, because it needs no pairing.

**Done when** every stage 1 and 2 call has a recorded example.

**Status:** finished 2026-11-04, awaiting review. Record: `opencode-api-stage0.md`, including what was not tested.

### Stage 1: basic chat through OpenCode
Add an OpenCode model option beside the current ones. Start the server on demand when it is
chosen and stop it when the shell or tab closes. Stream text with `curl --no-buffer` into a
`SplitParser`, as `Ai.qml` already does. Support model switching and a real stop button.
**Tools off**, enforced on the server by a `deny` rule on each session, not only hidden in the UI.
Check the rule in the create response before sending a prompt.

**Done when** a message streams into the existing bubbles, stop works, and no process is
left behind.

**Status:** done 2026-11-04 in patch 0014 and `opencode-tab`, tested in the real tab: streaming, stop, Enter
during a reply, server start on first message, server stop on switching to a direct model, nothing left behind.
The server starts on the first message, not when a model is picked, so a remembered model cannot
start it at login. It stops on switching to a direct model, after 15 idle minutes, or with the shell.
Limits for now: no attachments, a loaded chat or earlier direct-model messages are not sent to OpenCode,
and regenerate resends into the same session, so the old reply stays in OpenCode's context.

### Stage 2: safety and tools
Show Allow/Deny in the chat for every permission request, with the exact command or file.
Deny on timeout or error, from the client, since the server does not expire requests. Show tool steps such as "Reading file" and edits. Then retire
the panel.

**Done when** nothing but project reads runs without an explicit Allow, proven by a denied edit changing nothing
and by a read outside the project prompting.

**Status:** done 2026-11-05 in patch 0015. Tested in the real tab with a real model (denied edit changed nothing,
approved edit ran, card scrolls into view) and with 32 scripted attacks through a mock provider. See the stage 0 record.

### Stage 3: extras
Chat history from sessions, diffs, undo through revert, and the welcome screen, model menu,
pill input and better code blocks from the earlier UI list.

**Status:** done 2026-11-05 in patch 0015, except code blocks: `/history`, `/resume N`, `/diff`, `/undo`, a model menu on
the model chip, a new welcome text, and a rounder input. "Better code blocks" means IDE-style display, with colours and
line numbers. Built 2026-11-05 but not yet seen on screen or committed.

## Working rules learned the hard way

- **Test before claiming.** Clean logs missed real layout bugs. Screenshot UI changes.
- **Do not interrupt the user.** Ask before opening the sidebar or restarting the shell.
  Prefer hot reload. `hl.dsp.focus` tests fail while their mouse is over another window.
- **Never add an `IpcHandler` for testing.** A temporary one was at the site of a Quickshell
  SIGSEGV. A rejected tool call can still have partly run, so re-check state afterwards.
- **Restarting Quickshell:** `qs -c ii kill` can leave the old copy alive, giving two top
  bars (`hyprctl monitors` reserved top 80, not 40). Check `qs list --all`; `pgrep -x qs`
  misses `quickshell`. Kill the older PID.
- **Reload check:** `Configuration Loaded` count in `qs -c ii log`. The watcher can lag 8s.
- **Never hot reload while the screen may be locked.** `screenLocked` restarts as `false`, so the new shell drops the lock surface
  and Hyprland shows its crashed lockscreen page. The screen locks after 5 idle minutes, so ask first if the user may be away.
- **Escape closes the sidebar.** Anything typed next lands in the focused window. Check `hyprctl layers` before every
  keystroke when driving the tab, and never send Escape.
- **`ydotool mousemove --absolute` doubles coordinates here.** Halve them, and check `hyprctl cursorpos` before
  clicking. Focus follows the mouse, so a stray move changes the active window. Keyboard stays in the open sidebar.
- **`ls` is aliased to `eza`,** which can hang forever in a script waiting on stdin. Use `command ls`.
- **`pkill -f` matches your own shell.** Use PIDs. In zsh, `${m}:x` not `$m:x`, and avoid
  bare `===`.
- **QML:** `pressX` and `icon` are FINAL on Button. Harness tests: `/usr/lib/qt6/bin/qmltestrunner`
  (the one on PATH is Qt 5 and prints nothing), with an `Item` root holding a child `Window`, plus a
  control case that fails on purpose.
- **Model lists lie.** NVIDIA lists models a key cannot run. Test with the tab's real request.
- **Store message data before publishing its id** (`Ai.qml` had this backwards).
- **Commits:** ask before committing or pushing unless told to.

## Verifying a patch

Apply `0001`-`00NN` to a fresh `git -C ~/dots-hyprland archive 97c5bc65 dots/.config/quickshell/ii`
and diff against the live tree. Only `widgets/shapes` (a submodule) may differ.

## Unrelated open items

- Unconfirmed by the user: "hey" bubble wrapping, top bar spacing, app list search and padlock,
  Num Lock at reboot, real chat in the OpenCode panel.
- `custom/execs.lua`, `keybinds.lua`, `rules.lua` differ both ways between repo and live.
- 465 system updates pending; a Hyprland bump means rebuilding `hyprbars`.
- The OpenCode launcher, tab helper, config, `nvidia-ai` and the cursor script are on branch `opencode-ai-tab`, not `main` yet. Merge when ready.
- Tab loop incident, not reproduced: record the time and what opened.
