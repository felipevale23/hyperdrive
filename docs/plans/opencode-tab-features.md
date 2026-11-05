# Plan: more OpenCode features in the AI tab

Written 2026-11-05. Follows `opencode-ai-tab.md`, whose stages are done. Start here in a fresh
session, on branch `opencode-ai-tab` in `~/dev/sh/hyperdrive`, or a new branch once that one is merged.

Nothing below has been tested yet. The endpoints come from the OpenCode 2.0.24 spec, and stage 0
showed that the spec alone can mislead. Check each fact against a running server first.

## Where things stand (2026-11-05)

- Committed through `78a04b4` on `opencode-ai-tab`, pushed, and merged into local `main`, which is not pushed.
- Live but not committed: the `~/.agents` folder change and the IDE-style code blocks, which are also not seen on screen yet.
  Finish those first: check on screen, make patch `0017`, commit. See `~/.agents/todo.md`.
- The tab works in `~/.agents`, and `~/.agents/projects` is ready for work. `~/dev` always prompts.
- The mock provider, attack scripts and unit tests are in `~/.agents/projects/opencode-tab-tests`. `mock.py` listens on port 47011 and
  plays the model: a message containing `CALLS [["tool",{args}]]` makes it call those tools. Point a test config's `baseURL` at it.
- Run the unit tests with `/usr/lib/qt6/bin/qmltestrunner`, beside copies of the `services/ai` files. One control test fails on purpose.

## Rules for every phase

- **Prove the API first.** Use a mock provider or temporary XDG folders, so the real database stays clean.
  Test a non-git folder too: `~/dev` isn't a repo, and that broke undo the first time. `~/.agents` isn't one either.
- **Assume a new feature bypasses permissions until a test shows otherwise.** Attachments did. Every new
  way to run or send something needs an attack case, and the check belongs in `opencode-tab`, not the UI.
- **Nothing runs without an Allow,** except project reads. A feature that needs an exception gets a decision from the user.
- **Keep the model out of it.** Features the user triggers, such as a typed shell command, are fine. The
  model must not be able to reach them, or print something that looks like them.
- **Avoid `/api/experimental`,** or mark the feature as likely to break on upgrade.
- **Finish in the real tab,** with a real model and a screenshot. Check `session_v2` to prove the request
  went through OpenCode. Mock tests alone have hidden real bugs here.
- One patch per phase, verified on a fresh tree, as in `opencode-ai-tab.md`. Ask before committing.

## Phase 1: choose the project folder

Why first: the tab is limited to `~/.agents`, so it can't work on a repo without prompting for everything.
Picking a folder for one chat makes that deliberate, and gives OpenCode's git snapshots a chance to work.

- Add `/project`, with a picker from `GET /api/project` and folders the user chooses, plus a chip. Choosing a folder in
  `~/dev` must be deliberate, because the user keeps important files there.
- Pass the folder to the helper on each call. `FOLDER`, `safe_path`, `read_mentions` and `find` all
  depend on it, so one wrong value would widen what counts as "inside the project".
- Store the folder with the session, because `/resume` has to restore it. Don't remember it for new chats.
- Decide what happens on switching mid-chat. Suggested: start a new chat.
- Keep the patch-based `/undo`. Test whether `revert` with files is better in a real repo before changing it.

**Done when** a read outside the chosen folder prompts, `@` searches only that folder, and `/undo` works in
a repo and in a plain folder.

**Status (2026-11-05):** done in patch `0018`, tested in the real tab with Mistral Large 4 in a git repo: a read in the folder ran
without a prompt, `.git/config` prompted and Reject stopped it, an approved edit changed the file, `/diff` and `/undo` worked, `@` searched
that folder, `/clear` went back to `.agents`, and `/resume` restored the folder. `session_v2` shows the chat with that `directory`.
Plain folders were tested with the mock only. Open question: whether `~/GoogleDrive` and `~/Desktop/Photon` should be refused too.
The `/` button is hidden on OpenCode models, because the folder chip left no room. The chip cuts names at 10 characters.

- One server serves every folder: `POST /api/session` with `location.directory` works from a server started elsewhere,
  and the session stores it. So the session is the source of truth. `send` and `undo` read the folder from it, and a different
  folder passed for an existing chat is refused. Only a new chat takes a folder from the caller.
- `GET /api/fs/find` needs `location[directory]`. A plain `directory=` is ignored and searches the server's own folder, which
  the helper did until now without showing, because the two were the same.
- `GET /api/session` with no filter lists every folder, so `/history` covers them all. `GET /api/project` gives `canonical` paths.
- `revert` with `files: true` restored the file in a repo and did nothing in a plain folder. Patch-based `/undo` works in both, so it stays.
- Reads outside the session's folder arrive as action `external_directory` and prompt, with no help from the helper.
- A read of `.git/fake-secret` ran with no prompt. `.git` can hold tokens in remote URLs, so `safe_path` now also refuses `.git`,
  `.ssh`, key files and similar, in any part of the path.
- `check_folder` allows only real folders inside the home folder. It refuses the home folder itself, `.config`, `.local`, `.cache`,
  `.mozilla` and anything matching the private names. Symlinks are resolved first.
- Attack cases: `phase1.py` in `~/.agents/projects/opencode-tab-tests`, 81 checks, all passing. It needs `HOME` set to the lab folder.
- `/project` lists folders, `/project N` or `/project PATH` starts a new chat there, and `/clear` goes back to `~/.agents`.

## Phase 2: agents and subagents

Why now: subagents work, but only as cards and one line each. This phase makes them something you can see and tune.
All of it follows the rules above, and models, tokens and effort must be tested with the real NVIDIA key: model lists lie.

### See and control subagents

- Show each subagent as a live row in the chat: agent, task, model, state, tokens. The helper already follows the family.
- `/agents` lists this turn's subagents. Opening one shows its messages, read from its child session.
- Stop one subagent without ending the turn, with `POST /api/session/{child}/interrupt`. Test what the parent does next.
- Group cards by subagent, so it's clear who is asking. `always` stays refused, so each action still needs its own answer.
- Close a known gap: the `subagent` tool takes a `sessionID` to continue an old child. That child sends no `session.created`,
  so the helper won't follow it and its request would wait unseen. Either follow it, or deny calls with a `sessionID`.
- `model` and `background` are also set by the model, so show them clearly on the card.

### A model for each agent

- OpenCode supports this: `agent.<name>.model` in the config, for `build`, `plan`, `general` and `explore`.
- **Bug to fix first:** the tab forces the chip's model on the session, so `agent.plan.model` (Nemotron 3 Ultra) is ignored.
  Decided by the user: each agent keeps its own model, and the chip changes only the selected agent's.
- Test what wins for a subagent: its agent config, the parent's session model, or the tool's `model` argument.
- Add `/agent model NAME MODEL`, with a menu. Writing to `opencode.json` needs a reload (`opencode reload`), and the live
  file and repo copy must stay the same. Check whether the server picks it up without a restart.

### Effort for each model

- OpenCode's word for this is a **variant**: `provider/model#variant`, and `variant` on a session's model. `Model.Info.variants`
  lists what a model has. The config today uses `options.reasoningEffort: low` on two models, and none on the Nemotrons.
- Custom NVIDIA models may list no variants. If so, define `low`, `medium` and `high` in the config.
- **Prove it does something.** Send the same prompt at each level and compare reasoning tokens. A model can accept the setting
  and ignore it.
- Add `/effort low|medium|high` for the current agent, a chip, and effort in `/agent model`, as `MODEL#high`.

### Token usage for each agent

- `session.step.ended` and `session.usage.updated` report input, output, reasoning and cache tokens, per session. Child sessions
  report their own, so usage can be split by agent. Sum a family in the helper, because the tab shows only the parent's today.
- Add `/usage`: a table of agent, model, effort and tokens for this turn and this chat. Show the total in the chip.
- Show how full the context is, from `limit` in `Model.Info`, as a percentage. This also tells you when to use `/compact`.
- Cost was 0 on every test, because the NVIDIA models have no prices set. Show tokens, and add cost only if prices are configured.

### Also worth adding

- **Custom agents:** see below. The config takes `system`, `description`, `steps`, `permissions` and `model`.
- **Step limits:** `steps` caps a runaway agent. Set a default for subagents.
- **Notify on a waiting card:** a desktop notification when a card opens with the sidebar closed. Otherwise a long task hits
  the 2-minute timeout unseen.
- **Token budget:** a warning when a turn passes a set number of tokens.

### Custom agents: image, parser and video

Chosen by the user. Define each in `agent.<name>` with `mode: subagent`, so `@image`, `@parser` and `@video` work, and add them to
`SUBAGENTS` in the helper. The tab's session rules override an agent's `permissions`, so test what each can really do.

A chat model can't make an image or a video itself. These agents write the prompt and then call a tool, so each run shows a card.

| Agent | Works through | State |
|---|---|---|
| `image` | `nvidia-ai image "PROMPT"`, FLUX.1-dev, 1024x1024 | Ready to build. Tested 2026-11-04 |
| `parser` | `nvidia-ai parse FILE`, Nemotron 3.5 Super VL | Ready for images. PDFs need pages turned into images first |
| `video` | `ffmpeg`, local only: trim, join, convert, extract frames or audio | Ready to build. It edits video, it doesn't generate it |

- **Output folder:** `nvidia-ai image` saves to `~/Pictures/nvidia-ai`. Add an output option, and default to
  `~/.agents/projects/` so results stay inside the project.
- **`nvidia-ai parse` sends the file to NVIDIA.** It doesn't check the path, so read the card: a model could ask it to send
  `~/.ssh/id_rsa`. Add `safe_path`-style checks to the tool itself. The tab's read rules don't apply inside a shell command.
- **Don't auto-allow `nvidia-ai` in the shell rules.** A pattern like `nvidia-ai *` would also match `nvidia-ai x; rm -rf ~`.
  Keep the card, or later expose these as proper tools through a small MCP server, which also removes the shell.
- **Video stays local** (decided by the user). `ffmpeg` commands go through normal shell cards and write into
  `~/.agents/projects/`. Generating video would need a provider, since no model is reachable on this key (Cosmos routes return 404).

**Done when** two subagents on different models and effort levels run in one turn, each shows its own tokens, the totals match
the sessions in `opencode.db`, and stopping one leaves the other running.

## Phase 3: small commands

Each one is short and usable alone.

| Command | Endpoint | Check first |
|---|---|---|
| `/compact` | `POST /api/session/{id}/compact` | How the chat should look afterwards. It runs at a step boundary |
| `/fork` | `POST /api/session/{id}/fork` | Whether the fork keeps the permission rules. The helper re-checks them anyway |
| `/delete` | `DELETE /api/session/{id}` | Ask for confirmation. Also remove its journal. Clears test chats |
| Custom commands in `/` | `GET /api/command`, `POST .../command` | Commands may run shell or tools. Test for a bypass |
| Git chip | `GET /api/vcs`, `/vcs/status`, `/vcs/branch` | Needs phase 1 to mean anything |
| `!command` | `POST /api/session/{id}/shell` | Runs with no permission check, so it must only come from text the user typed |

**Done when** each works in the real tab, and `!` can't be triggered by model output.

## Phase 4: images

- Lift the block on attachments for models that take images, starting with Nemotron 3.5 Super VL.
- Reuse the tab's paste and `/attach`, sending through prompt `files`.
- Apply `safe_path`, or allow only files the user pasted. Decide which.
- The config warned that `attachment: true` is an unsupported setting, so confirm `modalities` is enough.

**Done when** a pasted screenshot is described correctly, and a text-only model gives a clear message.

## Phase 5: queue messages while a reply runs

- `delivery` on `POST .../prompt` takes `steer` or `queue`, and the spec lists a 409.
- The tab blocks Enter during a reply today. Queue the message instead, and show that it's waiting.
- Decide what stop does to a queued message. Suggested: keep it in the box, unsent.

**Done when** a queued message runs after the reply, and stop leaves nothing to run by surprise.

## Phase 6: skills, MCP and web search

These widen what the model can do, so each needs its own review.

- **Skills:** denied today. Read what `GET /api/skill` returns and what loading one can do. Allow by name, not all at once.
- **MCP:** `GET /api/mcp` is stable, but adding and connecting servers is under `/api/experimental`. Find the permission
  action names for MCP tools, and confirm they reach `* * ask`. Start with a read-only list.
- **Web search:** already offered to the model, and it asks first. Show results better, and read `GET /api/websearch/provider`.
  Pages can carry prompt injection, so treat everything after a fetch as untrusted, which the cards already do.

**Done when** each new tool call shows a card, and a denied one changes nothing.

## Phase 7: larger features, only if wanted

- **Worktrees:** `/api/worktree`. The agent works on a copy of a repo, which could replace most of undo. Needs phase 1.
- **Terminal in the tab:** `/api/pty`. A real terminal widget is a project of its own. Ask if `!command` is enough first.
- **Integrations and OAuth:** `/api/integration`. Find where tokens are stored first: the rule is keys in the keyring, never files.

## Staying blocked

`execute` stays denied. It's a JavaScript runtime that scripts tool calls and HTTP, so one Allow card
can't describe what it will do. `always` stays refused by the helper. Revisit neither without a decision from the user.

## Decisions from the user (2026-11-05)

- The project folder is **not** remembered between chats. Each new chat starts from the default folder, `~/.agents`, until
  `/project` picks another. `/resume` still restores the folder that chat used.
- The 2-minute permission timeout stays, for long tasks too.
- Each agent keeps its own model. The chip changes only the selected agent's.
- Custom agents wanted: image, parser and video. Video is local editing with `ffmpeg`, not generation.
