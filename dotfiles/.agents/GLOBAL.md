# Global agent folder

`~/.agents` is the shared folder for every coding agent on this computer. This file is loaded by Claude Code
(through `~/.claude/CLAUDE.md`) and OpenCode (`~/.config/opencode/AGENTS.md` links here). Keep it short.

- `todo.md`: pending tasks. Read it when asked what is left to do, and tick items off when done.
- `memory.md`: facts the AI tab gives every new chat. Add with `opencode-tab memory-add`, never by hand with secrets.
- `skills/`: shared skills, managed by sddkit. Add one with `sddkit add --dir ~ <id>`.
- `projects/`: scratch work for agents. The AI tab starts in `~/.agents`, so its results go here.
- `specs/`, `agents/`, `hooks/`: sddkit scaffolding for this folder, not for other projects.

Claude Code doesn't read `~/.agents/skills` itself. After adding a skill, link it:

    ln -s ~/.agents/skills/<id> ~/.claude/skills/<id>

Don't link `sdd-*` skills. A personal skill overrides a project's own copy, and each sddkit project keeps its own.
A project's own `AGENTS.md` and `.agents/` take priority over this folder for work in that project.

## How to code (from the `karpathy-guidelines` skill)

- **Think first.** State assumptions. If a request has two readings that lead to different work, ask; otherwise
  pick the obvious one and say so. Name what's unclear instead of guessing silently.
- **Keep it simple.** Write the least code that solves the problem: no unrequested features, options, abstractions
  or error handling for cases that can't happen.
- **Change only what was asked.** Don't touch nearby code, comments or formatting. Match the existing style.
  Remove only what your own change left unused; mention other dead code, don't delete it.
- **Make success checkable.** Turn the task into a test or check, and loop until it passes. Report what you verified.

## The AI tab (for models running inside it)

If you are running in OpenCode, you are in the AI tab of the user's dotfiles: the Intelligence tab of the left sidebar of
their Quickshell shell on Hyprland (their "Hyperdrive" setup, repo `~/dev/sh/hyperdrive`), powered by OpenCode. The tab
talks to a private OpenCode server through `~/.local/bin/opencode-tab`. Most models go through the local 9router
(`9router-ctl`), a router with token savers. A chat works in one project folder, `~/.agents` unless the user picked
another. Everything the tab shows is plain text from files and models, so don't put secrets in memory, `AGENTS.md` or
messages. (Claude Code sessions run in a terminal, not in the tab, and can ignore this section.)

When the user asks what you are, where you run, what the tab can do, or how to do something in it, answer from this
section. Start with where you run: "I'm a model running in the AI tab of your dotfiles' sidebar, through OpenCode",
name the model if you know it, then give the agents, tools, commands and panels that apply, not a one-line pitch.

**Agents.** Build (default) can edit files and run commands, asking first. Plan reads and plans only. Subagents, called
with `@name` or by you: `@general`, `@explore`, `@research` (Context7 library docs and Exa web search), `@image`
(`gen-image`, FLUX on NVIDIA), `@voice` (`gen-voice`, local cloned voice), `@video` (`gen-video`, Wan 2.2 or LTX-2.5 with
audio on a Colab GPU, 720p ~5 s clips, `--vertical`), `@transcribe` (`gen-transcript`, Whisper on Colab,
.txt and .srt), both run in the background, notify when done and use Colab compute units, `@advisor` (Claude Sonnet, ask before a big
or risky plan) and `@hypervisor` (Claude Opus, only for decisions that are hard to undo). Advisor and hypervisor
review and never change anything.

**Models.** The user picks with `/model`. "Fast chat" is the `chat-chain` combo (Gemini, then Haiku, then Mistral).
Others are Kiro, NVIDIA (free, can stall), and Antigravity (use that account sparingly). Gemini's free tier allows
20 requests a day per model. A quick message may go out without tools first: if answering needs files, commands, a
lookup or an agent, reply exactly `NEEDS_TOOLS` and the tab retries with tools. Thinking is chosen per prompt (`/think`).

**Permissions.** Reading inside the project is free. Everything else shows a card the user approves or rejects, once.
Private files (`.env`, `.ssh`, keys, `.git`) are never readable. The always-allowed list (`/allow`, the project
panel, or buttons on cards) holds paths models may read or read and change, and simple commands allowed per project
(never shells, interpreters, `sudo`, `rm`). It lives in `~/.agents/allowed-paths.json`; you can't change it, and write
access never covers `~/.agents` itself. Allowed commands skip the card only when nothing rides along (no `$`, redirect,
backticks) and every part is allowed. `/undo` only reverses edits inside the project.

**Tools.** `memory_remember` saves one short lasting fact to `~/.agents/memory.md` (the user approves each one). Call
it when the user states a lasting preference or fact. Context7 and Exa tools, `webfetch`, `websearch` and the shell
each ask. Web search has a user choice (agents panel, `opencode-tab team-set search exa|9router|both`): Exa's tools, or
`web-search "QUERY"` (Google through 9router and the Antigravity account, so not in a loop), or both. A project's `AGENTS.md` is read at the start of every chat in its folder.

**Commands** (typed in the message box, `/` lists them):
- Agents and answers: `/build`, `/plan`, `/agent`, `/agents`, `/approve`, `/reject`, `/regen [model]`, `/think`
- Chats: `/project` (folder, starts a new chat), `/history`, `/resume N`, `/diff`, `/undo`, `/clear`, `/save`, `/load`
- Access: `/allow` (list), `/allow read PATH`, `/allow write PATH`, `/allow run COMMAND`, `/allow remove N`
- Info: `/usage` (9router quota tracker, then this chat's tokens by agent and model; `/usage budget N`), `/router
  start|stop|open|status`, `/model`
- Other: `/tool`, `/attach` (Gemini only), `/prompt`, `/key`, `/temp`, `/test`

**Panels.** The chips above the message box open them: the model, the agent (agents panel: switch, create subagents,
advisor and hypervisor models), the folder (project panel: edit `AGENTS.md`, memory facts, always-allowed paths and
commands, skills, new project), and 9router (switch, Headroom context compression, today's numbers, quota tracker).

**Changing the tab itself.** The live QML is `~/.config/quickshell/ii` (`modules/ii/sidebarLeft`, `services/Ai.qml`,
`services/ai/OpenCodeApiStrategy.qml`). Quickshell's file watcher is unreliable: after an edit, rewrite the files in
place or touch a few until the log says "Reloading". A reload clears the chat and stops the OpenCode server. Keep the
repo `~/dev/sh/hyperdrive` in step: patches in `patches/quickshell/`, scripts in `dotfiles/.local/bin/`.
