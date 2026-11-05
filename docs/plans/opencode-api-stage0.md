# OpenCode API: stage 0 record

Tested 2026-11-04 on OpenCode 2.0.24 with curl against temporary servers. Companion to
`opencode-ai-tab.md`. Everything here was observed unless it is marked as coming from the
spec or listed under "Not tested". Re-test after an OpenCode upgrade.

The test servers used their own XDG folders and a scratch git repo, so the real
`opencode.db` and config were not touched. Prompts went to NVIDIA with the keyring key.

## Decisions for stage 1 and 2

| Question | Answer |
|---|---|
| Authentication | The tab runs its own `opencode serve` with a random password per launch in `OPENCODE_SERVER_PASSWORD`. No pairing. |
| Port | `--port 0`, then read `server listening on http://127.0.0.1:PORT` from the output. Never 49374: the background service takes that one. |
| Password in curl | Use a `curl -K` config, not `-u`, which shows the password in the process list. |
| Tools off (stage 1) | Create every session with `permissions: [{"action":"*","resource":"*","effect":"deny"}]`. |
| Tools on (stage 2) | Same field with `"effect":"ask"`. `PATCH /api/session/{id}` changes it on a live session. |
| Config | The tab can use the normal config, because session rules override it. See the warning below. |
| Deny button | Reply `reject` with **no message**. This stops the turn. |
| Timeout | The client must enforce it, by sending the same `reject`. The server does not expire requests. |
| Stop button | `POST /api/session/{id}/interrupt`. |
| Shutdown | SIGTERM to the server is enough. |

**Warning: fail closed.** Without session rules, the normal config allows nearly everything,
so a session created without `permissions` has tools fully on. After creating a session,
check that the response contains the expected rules, and do not send a prompt if it doesn't.

## Calls

`$B` is `http://127.0.0.1:PORT`. Every call uses `curl -s -K auth.cfg`, where `auth.cfg` holds
`user = "opencode:PASSWORD"`.

```sh
# Start. Keys go only into this process's environment.
OPENCODE_SERVER_PASSWORD=... NVIDIA_API_KEY=... opencode serve --hostname 127.0.0.1 --port 0

# Create a session. Returns {"data":{"id":"ses_...","permissions":[...],...}}
curl -X POST $B/api/session -H 'Content-Type: application/json' -d '{
  "title":"...", "location":{"directory":"/path/to/project"},
  "permissions":[{"action":"*","resource":"*","effect":"deny"}]}'

# Listen. One stream for the whole server: filter by data.sessionID.
curl --no-buffer -H 'Accept: text/event-stream' $B/api/event

# Send. Returns 200 straight away; the reply arrives on the event stream.
curl -X POST $B/api/session/$ID/prompt -H 'Content-Type: application/json' -d '{"text":"..."}'

# Switch model. Returns 204, even for a model that does not exist.
curl -X POST $B/api/session/$ID/model -H 'Content-Type: application/json' \
  -d '{"model":{"id":"minimaxai/minimax-m3.1-flash","providerID":"nvidia"}}'

# Stop. Returns {"interrupted":true}, or false if the session was idle.
curl -X POST $B/api/session/$ID/interrupt

# Pending requests. Returns {"data":[{id,sessionID,action,resources,save,metadata,source}]}
curl $B/api/session/$ID/permission

# Answer. Returns 204, or 404 if the request is gone.
curl -X POST $B/api/session/$ID/permission/$REQ/reply \
  -H 'Content-Type: application/json' -d '{"decision":"once"}'     # or "reject"

# History. Types: user, assistant, idle, model-switched and others.
curl "$B/api/session/$ID/message?order=asc"

# Change rules on a live session. Returns 204.
curl -X PATCH $B/api/session/$ID -H 'Content-Type: application/json' \
  -d '{"permissions":[{"action":"*","resource":"*","effect":"ask"}]}'

# Delete. Returns 204.
curl -X DELETE $B/api/session/$ID

# Stage 3: diff and undo. Use the id of the user message to go back to.
curl $B/api/session/$ID/diff
curl -X POST $B/api/session/$ID/revert/stage -H 'Content-Type: application/json' \
  -d '{"messageID":"msg_...","files":true}'      # restores files, keeps messages
curl -X DELETE $B/api/session/$ID/revert         # cancels: files come back
curl -X POST $B/api/session/$ID/revert/commit    # final: messages are dropped too
```

For the model menu, `GET /api/model` returned 63 entries from `nvidia`, `opencode` and `google`,
so filter it. `GET /api/model/default` returned `data: null` even with `model` set in the config.
Read the default from the agent instead: `GET /api/agent`, then `build.model`.

## Event stream

Standard SSE with `data: {json}` lines, no `event:` field, and `: heartbeat` comment lines. The
JSON type is in `.type`, and the payload is in `.data`. The first event is `server.connected`.

A normal turn: `session.inbox.enqueued`, `session.execution.started`, `session.inbox.delivered`,
then for each step `session.step.started`, `session.reasoning.*`, `session.text.started`,
`session.text.delta` (many), `session.text.ended`, `session.step.ended`,
`session.usage.updated`, and finally the end event.

A turn ends with exactly one of these:

| Event | Meaning |
|---|---|
| `session.execution.succeeded` | Finished |
| `session.execution.interrupted` | `reason: "user"` after interrupt, `"shutdown"` after a reject with no message |
| `session.execution.failed` | `data.error` has `type` and `message`, for example `provider.no-route` |

For the UI:

- Append `session.text.delta` `.data.delta`. `session.text.ended` carries the full text.
- Reasoning arrives separately in `session.reasoning.delta`. Keep it out of the reply bubble.
- **A turn can succeed with no text at all.** This happened in a tools-off session when the model
  was told to use tools: it stopped after one output token. Show a message, not an empty bubble.
- **The first reply can be slow.** Mistral Large 4 took about 30s to start on a 7.4k token prompt.
  Show a waiting state from `session.execution.started`.
- Errors from a bad model appear only here, not on `POST /model`.
- An interrupted reply keeps its partial text, and no deltas arrived after the interrupt.
- A long turn sent 171 deltas, so keep the per-delta work small.
- `curl` exits with code 18 when the server stops. That is normal, not a crash.
- The spec says slow readers get dropped and missed events are not replayed. After a reconnect,
  reload with `GET .../message` and `GET .../permission`.

## Permissions

Rules are evaluated in order and **the last match wins**. Session rules override agent and config
rules, for `build` and `plan` alike. `deny` also removed the tools from the request: input fell
from about 7,450 tokens to 389, and no tool call was attempted. A file edit requested in that
session changed nothing.

The flow: `session.tool.input.started`, `session.tool.input.ended`, `session.tool.called`,
`permission.asked`, `permission.replied`, then `session.tool.success` or `session.tool.failed`.

What to show on the Allow/Deny card:

- `action` is `edit`, `read` or **`shell`, not `bash`**, although the model calls it the bash tool.
- For `shell`, `resources[0]` is the exact command.
- For `edit`, `metadata.files[].patch` is the exact diff, before anything is written.
- `source.id` links the request to the tool call.

| Reply | Result |
|---|---|
| `once` | Runs that one call. An identical later call asks again. |
| `reject`, no message | Tool fails with `aborted`, and **the turn ends**. File unchanged. |
| `reject` with `message` | Tool fails with `permission.rejected`, and **the model carries on**. In one test it retried and raised 4 requests. File unchanged. |
| No reply | Still pending after 75s, the longest wait tested. |
| Interrupt while pending | Request cleared, tool not run, and a late reply gets 404. |

- **A reject clears everything pending in the session**, with a `permission.replied` event for
  each. `once` clears only its own request. So close cards from `permission.replied` events, not
  from the button that was pressed, and expect 404 on a second reply.
- Models can issue parallel tool calls, so several cards can be open at once.
- With `* * ask`, every `read` also prompts, including of ordinary files. Do **not** fix that with a
  `read * allow` rule. See "Found while building stage 2".
- `POST /api/session/{id}/permission` evaluates a rule without a model, which makes it a good
  test tool. It creates a real pending request when the result is `ask`.

**Quirk:** with no session rules, the first evaluation in a directory the server has not used
returned `deny`, then correct results after that (3 of 3 runs). With session rules, the first
result was correct, and a real tool call in an unused directory prompted normally. It never
returned anything looser than the rule, so it is harmless, but it can confuse testing.

## Server lifetime

- Sending SIGTERM while a shell tool ran `sleep 300` stopped the server in 0.4s, killed the
  `sleep`, closed the port, and ended the event `curl`. Nothing was left behind.
- A plain `opencode serve` starts no service. `opencode-app` only kills `serve --service`, so it
  will not touch the tab's server.
- Any CLI call that needs a server, such as `opencode session list`, starts
  `opencode serve --service` on 49374. It has no API keys unless the caller exported them.
  `--help`, `--version` and `debug paths` do not start one.
- `/api/*` and `/openapi.json` return 401 without auth. `/session` returns the web app's HTML.

## Found while building stage 2

- **Tools offered to the model:** `edit`, `execute`, `glob`, `grep`, `question`, `read`, `shell`, `skill`,
  `subagent`, `webfetch`, `websearch`, `write`. A `* * deny` rule sends an empty list, confirmed by recording the request.
- **The tab denies** `execute` (a JavaScript runtime that scripts other tools), `question` (needs a form) and `skill`.
  Subagents were denied here too until patch 0016. A model that calls one anyway
  gets "No tool named ...".
- **Rules match the path as written.** With `read * allow`, a symlink in the project read a file outside it with no
  prompt. So all reads ask, and the helper answers `once` only when the resolved path is inside the project and neither
  the path nor its target is an env file. Links out of the project, and links to `.env`, show a card.
- **`grep` and `glob` always ask**, because they could read a `.env` without touching its `read` rule.
- `write` asks as action `edit`, and keeps no patch afterwards. The helper saves the permission request's patch in
  `~/.local/state/opencode-tab/`, mode 600, so `/diff` and `/undo` can use it.
- **`/diff` and `revert` with files need git.** `~/dev` isn't a repo, so `GET .../diff` returned nothing and `revert` with
  `files: true` restored nothing while reporting success. The helper reverses the recorded patches with `patch -R`
  instead, keeps a backup in memory, and drops the turn only if every patch applied. Shell commands can't be undone,
  and the tab says so.
- A card's code fence has a random name. Approve buttons appear only on that fence, because the model can print a
  `command` block of its own into the same message.
- A hot reload stops the tab's server but can leave a stale `server.json`. The next start replaces it.

## Found while adding agents and @ mentions (patch 0016)

- **Session rules override the agent's own.** Under `* * ask`, Plan's `edit` was `ask`, not denied. The tab's Plan rules
  deny `edit` and `shell`, so neither is offered, and that holds inside subagents.
- **Prompt `files` skip every permission check.** `.env`, files outside the project and symlinks out were all sent to the
  model with no prompt. The helper resolves each @mention and refuses anything `safe_path` rejects. Folders send a listing only.
- `GET /api/fs/find?directory=...&query=...` works without git, is ranked, returns folders with a trailing slash, and skips
  `.env` and symlinks. The helper filters it again anyway.
- **Subagents** run in child sessions announced by `session.created` with a `parentID`. They inherit the session's rules.
  The helper follows that family, sends child requests to cards with their own session id, and interrupts children when the
  turn ends, because `background: true` could outlive it. A denied child fails the subagent, and the parent may carry on and ask for other things.
- In QML, `onTextChanged` can run before bindings on the same text update. Compute from the text directly.

## Not tested

- The `always` reply, and `GET /api/permission/saved`. The helper refuses `always`.
- Google models through OpenCode. Only the NVIDIA key was given to the test servers.
- Sending a prompt while a turn is running. The tab blocks this (`delivery` is `steer` or `queue`; 409 is in the spec).
- Image input through `files`.
- Event stream overflow and reconnecting.
- Whether a pending request ever expires beyond 75s. The client timeout makes this irrelevant.

## Recorded payloads

Real events with paths replaced and the `durable` field removed. Session and message ids are real
but belong to throwaway test sessions.

```json
{"id":"evt_1a93da7c7001o0BN66MOCDlVGg","type":"server.connected","data":{}}
{"id":"evt_1a93e2ecd00177ynjiKXl7UtKd","created":1793840787149,"type":"session.execution.started","data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt"}}
{"id":"evt_1a93ea283001qXQG3FRjCzCMJf","created":1793840816772,"type":"session.reasoning.delta","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt","assistantMessageID":"msg_1a93e2f00001p3TsmjVH4KGwyP","ordinal":0,"delta":"The user wants an exact reply."}}
{"id":"evt_1a93ea2b9001U03qeNJUTk7QiI","created":1793840816825,"type":"session.text.delta","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt","assistantMessageID":"msg_1a93e2f00001p3TsmjVH4KGwyP","ordinal":0,"delta":"stage zero works"}}
{"id":"evt_1a93ea2ba00182y2QRZMnOXLni","created":1793840816826,"type":"session.text.ended","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt","assistantMessageID":"msg_1a93e2f00001p3TsmjVH4KGwyP","ordinal":0,"text":"stage zero works"}}
{"id":"evt_1a93ea2ca001A0Bu5QuknsqK1C","created":1793840816843,"type":"session.step.ended","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt","assistantMessageID":"msg_1a93e2f00001p3TsmjVH4KGwyP","finish":"stop","rawFinish":"stop","cost":0,"tokens":{"input":7452,"output":6,"reasoning":7,"cache":{"read":0,"write":0}},"snapshot":"6e7f38cd3ce49e8e378090ea96ad4d305debb003","files":[]}}
{"id":"evt_1a93ea2d1001CfsrARugiS7loq","created":1793840816849,"type":"session.execution.succeeded","data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt"}}
{"id":"evt_1a9414a360013kYLKf8JLMkipW","created":1793840990775,"type":"session.step.failed","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt","assistantMessageID":"msg_1a94144ba001Xd4bxc6RzYQhhJ","error":{"type":"aborted","message":"Step interrupted"},"snapshot":"6e7f38cd3ce49e8e378090ea96ad4d305debb003","files":[]}}
{"id":"evt_1a9414a3e0018qDy42mb5mI6w1","created":1793840990782,"type":"session.execution.interrupted","data":{"sessionID":"ses_e56c20ec9ffeYVPC4Wg9w7TWzt","reason":"user"}}
{"id":"evt_1a94329c80011gBEsM5jGxOnFo","created":1793841113544,"type":"session.revert.staged","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56be2de7ffews1kC7aSAht2XH","revert":{"messageID":"msg_1a9426f4a0014nZlXW3RYOLqPl","snapshot":"c6afc955e63a04287236c9708886e1e2ad4ac65d","files":[{"file":"note.txt","status":"modified","additions":1,"deletions":1,"patch":"diff --git a/note.txt b/note.txt\nindex 94c0724..610b431 100644\n--- a/note.txt\n+++ b/note.txt\n@@ -1 +1 @@\n-goodbye from the sandbox\n+hello from the sandbox\n"}]}}}
{"id":"evt_1a94329fe001UJItI3Q438Jm75","created":1793841113598,"type":"session.revert.cleared","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56be2de7ffews1kC7aSAht2XH"}}
{"id":"evt_1a9432a41001BxLp9nF1KqtXgs","created":1793841113665,"type":"session.revert.committed","location":{"directory":"/path/to/project"},"data":{"sessionID":"ses_e56be2de7ffews1kC7aSAht2XH","to":"msg_1a9426f4a0014nZlXW3RYOLqPl"}}
{"id":"evt_1a9481349001HJ1nobN6xPQeSm","created":1793841435465,"type":"session.execution.failed","data":{"sessionID":"ses_e56b7ed0cffe5OhKx2M4O4ix6p","error":{"type":"provider.no-route","message":"Model unavailable: nvidia/no/such-model"}}}
{"id":"evt_1a946713e001OQBhsEYb3aaFH1","created":1793841328446,"type":"session.execution.interrupted","data":{"sessionID":"ses_e56b9988fffem3MXH77C988QXV","reason":"shutdown"}}
```

Permission flow for a denied edit, then an allowed one, and a reject with no message:

```json
{"id": "evt_1a941e89b001bHUcluZEtpIB0F", "created": 1793841031323, "type": "session.tool.called", "location": {"directory": "/path/to/project"}, "data": {"sessionID": "ses_e56be2de7ffews1kC7aSAht2XH", "assistantMessageID": "msg_1a941e2f2001bdCY71DTlDeyy2", "id": "cc39454fd", "input": {"path": "note.txt", "oldString": "hello", "newString": "goodbye"}, "executed": false}}
{"id": "evt_1a941e8b000256A2z87vq7EQXw", "created": 1793841031344, "type": "permission.asked", "location": {"directory": "/path/to/project"}, "data": {"id": "per_1a941e8b0001XZCLigQcknOuDT", "sessionID": "ses_e56be2de7ffews1kC7aSAht2XH", "action": "edit", "resources": ["note.txt"], "save": ["*"], "metadata": {"files": [{"file": "note.txt", "patch": "Index: note.txt\n===================================================================\n--- note.txt\n+++ note.txt\n@@ -1,1 +1,1 @@\n-hello from the sandbox\n+goodbye from the sandbox\n", "status": "modified", "additions": 1, "deletions": 1}]}, "source": {"type": "tool", "messageID": "msg_1a941e2f2001bdCY71DTlDeyy2", "id": "cc39454fd"}}}
{"id": "evt_1a941e8bf0010tT2DbFxqlZHGG", "created": 1793841031359, "type": "permission.replied", "location": {"directory": "/path/to/project"}, "data": {"sessionID": "ses_e56be2de7ffews1kC7aSAht2XH", "requestID": "per_1a941e8b0001XZCLigQcknOuDT", "reply": "reject"}}
{"id": "evt_1a941e8c0001fhmw2lWCvgUw57", "created": 1793841031360, "type": "session.tool.failed", "location": {"directory": "/path/to/project"}, "data": {"sessionID": "ses_e56be2de7ffews1kC7aSAht2XH", "assistantMessageID": "msg_1a941e2f2001bdCY71DTlDeyy2", "id": "cc39454fd", "error": {"type": "permission.rejected", "message": "stage 0 test"}, "executed": false}}
{"id": "evt_1a942c82b001rnV5jqh37Z7A1D", "created": 1793841088555, "type": "session.tool.success", "location": {"directory": "/path/to/project"}, "data": {"sessionID": "ses_e56be2de7ffews1kC7aSAht2XH", "assistantMessageID": "msg_1a9426f5c00150ebvWegxgu1e5", "id": "15f97a97b", "content": [{"type": "text", "text": "Edited note.txt (1 replacement)"}], "metadata": {"files": [{"file": "note.txt", "patch": "Index: note.txt\n===================================================================\n--- note.txt\n+++ note.txt\n@@ -1,1 +1,1 @@\n-hello from the sandbox\n+goodbye from the sandbox\n", "status": "modified", "additions": 1, "deletions": 1}], "truncated": false}, "executed": false}}
{"id": "evt_1a9467124001U4pIoxJuUC95sw", "created": 1793841328420, "type": "session.tool.failed", "location": {"directory": "/path/to/project"}, "data": {"sessionID": "ses_e56b9988fffem3MXH77C988QXV", "assistantMessageID": "msg_1a946680300153digZ87E4ffeT", "id": "eed671078", "error": {"type": "aborted", "message": "The user declined this tool call"}, "executed": false}}
```
