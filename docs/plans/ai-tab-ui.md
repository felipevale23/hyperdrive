# Plan: AI tab interface

Written 2026-11-05. Follows `opencode-tab-features.md`, phase 1 of which is done in patch `0018`. Start here in a fresh session.
Part 1 fixes what the tab already shows. Part 2 brings the OpenCode web app's features into the tab.

Nothing below is built. The problems come from real-tab screenshots taken 2026-11-05. The web feature list comes from text in the
web app's code, not from using it, so open the app and confirm each row before building that panel.

## Decisions from the user (2026-11-05)

- **Keep the current Material look.** No new visual direction: same `Appearance` colours, rounding, fonts and animations.
- Fix order: not confirmed yet. Suggested below.

## Rules for every step

All the rules in `opencode-tab-features.md` and `opencode-ai-tab.md` apply. These are added for UI work:

- Reuse the widgets in `modules/common/widgets`: `SecondaryTabBar`, `StyledListView`, `DialogButton`, `RippleButton`. Colours come
  from `Appearance.colors`, never hex values.
- Sentence case, to match Material and the rest of the tab.
- **A model must not be able to fake the interface.** Anything that means "the system did this" needs the secret fence that
  permission cards use. Plain markdown can't carry it: today a model can print `` `read: note.txt` `` and look like a tool step.
- **The helper stays the security boundary.** Every new panel reads through `opencode-tab`, so `safe_path` and `check_folder`
  apply. QML never calls the server directly.
- Keep `test_card_has_secret_fence` and `test_fence_in_command_cannot_escape` passing, and add attack cases for new blocks.
- Finish in the real tab with a screenshot. Crop to the sidebar, because other windows can hold private messages.
- One patch per step, verified on a fresh tree. Ask before committing, and before opening the sidebar or hot reloading.

## Skills

All are in `~/.agents/skills`. None knows QML, so they supply rules and critique, not code.

| Skill | Use it for | Don't use it for |
|---|---|---|
| `apple-design` | `references/hig/generative-ai.md` for control, consequences and feedback; `disclosure-controls.md`, `feedback.md`, `loading.md`; a five-lens review of screenshots after each step | Platform conventions: menu bar, title case, Liquid Glass. The tab is Material |
| `ui-ux-pro-max` | `search.py "<query>" --domain ux` for one concern at a time, with the rule priority table as a checklist | `--design-system` and `--stack`: it has no QML stack and the look is decided |
| `frontend-design` | The "Restraint and self-critique" pass: remove one thing, and check that structure says something true | Palette, type or layout direction |

Not used: `impeccable` and `design-taste-frontend`, which work on web code and pages. sddkit's `ui` and `ui-reviewer` roles only
target web files, so follow their checklist by hand: every state, keyboard use, contrast of at least 4.5:1, nothing by colour alone.

## Part 1: fix what's there

### Step 1: a turn you can follow (patch `0019`)

Files: `OpenCodeApiStrategy.qml`, `AiMessage.qml`, `MessageCodeBlock.qml`, `MessageThinkBlock.qml`, `StringUtils.qml`.

1. **Permission cards.** Today a card is a code block, labelled "Markdown · 1 line" for a path. Make it its own block:
   - A header saying who asks and what it does, in words: "OpenCode wants to edit note.txt".
   - The reason it's asking, when the helper knows it: outside the project, private file, runs a command.
   - What Allow does, such as "Runs once. `/undo` won't reverse a shell command".
   - The detail below: path, command, or diff. Keep the buttons out of the code area.
   - Reject and Approve are the same size, with no default action. Add keyboard use, and check that typing in the input can't trigger one.
   - The answered state keeps the header and shows the outcome with an icon and a word, not colour alone.
2. **Thought rows.** Show a row only when it has content. Merge neighbouring rows in a turn into one, and keep them collapsed.
3. **Tool steps.** Add a `tool` block with a secret fence, in one quiet line: icon, verb, project-relative path. Failures show why.
   "Read note.txt", not `read: /home/.../note.txt`. Merge repeats, such as "Read 4 files", and expand on click.
4. **System messages.** Give `interfaceRole` its own quiet style, so "New chat in…" can't pass as a reply.

`generative-ai.md`: "Consider consequences and get permission before performing irreversible or potentially problematic tasks", and give
"specific, reassuring feedback during generation". So the in-progress state names the current step, not only "Thinking".

**Done when** a turn with a read, a denied read and an approved edit reads top to bottom without explanation, the answer sits within one
screen of the question, and a model printing fake tool steps or fake cards gets plain text.

**Status (2026-11-05):** done in patch `0019`, tested in the real tab with Mistral Large 4: reads merge into "Read 2 files", a denied and an approved
card, a failed step that opens by itself, `/approve`, and the turn fits one screen.

- Every OpenCode reply has a random `systemFence`. Cards, tool steps and notes are one line of JSON in it, or in the card's own fence while live.
  `StringUtils.splitMessageBlocks` pulls them out **before** markdown, so an unclosed fence or `<think>` from a model can't hide a card.
- Thoughts and tool steps next to each other become one activity row. Direct models don't have a fence and keep the old blocks.
- `/approve` and `/reject` are the keyboard path, because Tab in the input is taken by suggestions. They work during a reply.
- The helper sends a `step` event when a tool starts, and paths inside the folder are relative.
- `colSubtext` is 2.1 to 2.8:1 on these surfaces, and `colError` text 3.2 to 4.2:1, both under 4.5:1. The new blocks use `colOnSurfaceVariant`
  (6.1 to 7.9:1) and keep red for icons. The rest of the tab still uses `colSubtext`: Step 2.
- Unit tests: `tst_opencode.qml` and `tst_blocks.mjs`. A real model refused to print a fake card, so only the parser tests prove that case.
- Not checked on screen: Tab focus on the card's buttons, Copy on a message with blocks, a saved chat, a subagent card.

### Step 2: polish (patch `0027`)

1. **Status pill** covers messages on scroll. On OpenCode models, take it out of the overlay. Tokens move to the Context panel in Part 2.
   Until then, reserve its height so it can't overlap.
2. **Diff cards.** The filename becomes the header, with `+3 −1`. Drop the `Index:` and `=====` lines in the strategy, not in the helper,
   because `/undo` needs the patch whole. Add a change marker, so diffs don't rely on red and green alone.
3. **Scroll to bottom.** Use a quieter colour role and an icon only, placed so it doesn't cover the last line.
4. **Bottom row.** Patch `0021` widened the left sidebar to 560 px, so all chips and `/` fit. Check the row with the longest model and folder names.
   Suggested: move Tool into the `/` menu, since it rarely changes.

5. **Contrast.** Replace `colSubtext` on text in the tab with `colOnSurfaceVariant`, as Step 1 did for its blocks.

**Done when** nothing overlaps or clips at 460 and 750 px, measured contrast passes, and every control has a hover state and a tooltip.

### Step 3: `/resume` keeps the whole story (patch `0028`)

`messages()` in the helper drops tool parts, so a denied turn comes back as a question with no answer. Return tool parts and rebuild
steps and answered cards from them. Old cards must come back answered and can't be actionable.

**Done when** a resumed chat matches the original, and no card from history can be approved.

## Subagent robots (patch `0020`, done 2026-11-05)

Each subagent gets a live row under the reply: a pixel art robot, its job, what it's doing, its model and tokens.

- `PixelRobot.qml` draws three 14 by 14 sprites on a `Canvas` in theme colours: `general`, `explore`, and `other` for custom agents.
  States: working (two frames), waiting (question mark, red antenna), done (happy eyes), failed or stopped (grey, red eyes).
- The rows live in `message.subagents`, not the text, so a model can't print one and they update without touching the markdown.
- Events, all checked on a server: `session.created` with `parentID` gives `agent` and `title`, `session.step.started` gives `model`,
  `session.usage.updated` gives tokens, and the child's terminal event gives the end state. The helper turns these into `agent` events.
- A finished row stays finished, and anything still running when the turn ends shows stopped.
- Not done: stopping one subagent, `/agents`, opening one to read its messages. `/resume` loses the rows, like the rest of Step 3.

## Part 2: OpenCode web in the tab

The tab keeps its role as a sidebar. It gets what you'd open the web app for, not a copy of every setting.

| Web app | In the tab | Needs | Status |
|---|---|---|---|
| Sessions list: new, rename, delete, archive | Chats panel | Features phase 3 for delete | Step 5 |
| Fork, compact, undo, redo | Chats panel and commands | Features phase 3. Redo is new: test `DELETE .../revert` | Step 5 |
| Projects list, open project | Chats panel, grouped by folder | Done in `0018` | Step 5 |
| Review: changed files, unified and split diff | Changes panel | `GET /api/vcs/*`, `opencode-tab diff` | Step 6 |
| Context usage, tokens, cost | Context panel | Session fields, `session_v2` | Step 7 |
| Todo list | Context panel | Check where the todo tool stores it | Step 7 |
| Subagents | Context panel, live rows in chat | Features phase 2 | After Step 7 |
| Model and agent choice | Chips, already there | Each agent's model: features phase 2 | Phase 2 |
| File explorer, open file, search | Files panel | `GET /api/fs/list`, `/fs/read`, `/fs/find` | Step 8 |
| Commands | `/` menu, custom commands added | Features phase 3 | Phase 3 |
| Attach files | `@` and paste | Images: features phase 4 | Phase 4 |
| Queue messages | Input box | Features phase 5 | Phase 5 |
| MCP, skills | Read-only list in Context | Features phase 6 | Phase 6 |
| Worktrees | Not yet | Features phase 7 | Later |
| Terminal | Not in the tab. Decide after `!command` | Features phase 7 | Ask |
| Providers, servers, plugins, integrations, export | Not in the tab. Keep using the web app or config | Keys stay in the keyring | Out |
| Theme, fonts, shortcuts, notifications, language | Not needed: the shell owns these | | Out |

### Step 4: panels (patch `0029`)

A `SecondaryTabBar` under the header, shown only on OpenCode models. Direct models keep today's layout.

```
┌───────────────────────────────┐
│ Chat  Chats  Changes  Files  ⓘ│   ⓘ = Context
├───────────────────────────────┤
│                               │
│  panel                        │
│                               │
├───────────────────────────────┤
│ message box (Chat only)       │
│ model · agent · folder        │
└───────────────────────────────┘
```

Panels load when opened, not at start, so the server still starts on the first real use. Each has loading, empty, and error states.
At the 750 px width (`Ctrl+O`), Changes and Files can show a list beside the content. Test that `Ctrl+O` still works with the bar in place.

**Done when** panels switch by mouse and keyboard, the open chat survives switching, and direct models look unchanged.

### Step 5: Chats panel (patch `0030`)

Replaces typing `/history` and `/resume N`. Chats grouped by folder, newest first, with a search box. Click to resume, and the folder comes
with it. Rename through `PATCH /api/session/{id}`. Delete asks first and removes the journal. Keep the commands working.

**Done when** the test chats can be deleted from the panel, and a chat in another folder opens with the right chip.

### Step 6: Changes panel (patch `0031`)

The files this chat changed, each opening its diff, with undo for the last turn. In a git repo, a second view shows all uncommitted changes
from `GET /api/vcs/diff`. In a plain folder only the chat's own view exists, because OpenCode has no snapshots there. Read-only otherwise:
no stage or commit buttons.

**Done when** the numbers match `git diff` in a repo, and a plain folder shows the chat's changes with a clear note.

### Step 7: Context panel (patch `0032`)

Tokens against the model's limit, cost, model and agent, folder, and the todo list. Tokens leave the status pill here.

**Done when** totals match the session in `opencode.db`.

### Step 8: Files panel (patch `0033`)

A tree of the chat's folder, a read-only viewer using the code block, and search. A click on "Add to message" inserts an `@` mention, so
the normal checks run. New helper commands `list` and `read`, both limited by `safe_path`. Private files show with a padlock and no content.

Attack cases first: symlink out of the folder, `.env`, `.git/config`, `..`, a folder swapped for a symlink between `list` and `read`.
Viewing must never send anything to the model.

**Done when** every case refuses, and a file's content reaches the model only through an `@` the user added.

## Order

1. Steps 1 and 2, since everything later reuses those blocks.
2. Features phase 2 can start after Step 1: its live subagent rows extend the `tool` block.
3. Steps 4 to 8 in order. Step 3 fits anywhere after Step 1.

## Open questions

- Is the fix order above right?
- Do you use the web app's terminal? If so, is `!command` enough?
- Panels in the sidebar, as above, or should `Ctrl+O` open a wider two-column layout by default on OpenCode models?
- After Step 8, keep `opencode-app`, or remove it? The to-do already asks this.
