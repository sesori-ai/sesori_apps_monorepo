# Cursor Plugin Full Regression Test Plan

## Status

- **Purpose:** Reusable regression runbook for the production Cursor plugin.
- **Last reviewed:** 2026-08-10
- **Scope:** Cursor CLI, ACP, the Sesori bridge, relay delivery, and the iOS
  client.
- **Evidence policy:** Keep raw prompts, transcripts, source paths, image bytes,
  tokens, logs containing private payloads, and screenshots outside the
  repository. Commit only privacy-safe plans and reports.

This is a test plan, not a test result. A completed run should copy the matrix
into a dated stability report and fill in the result columns without changing
the reusable expectations here.

## Goals

The run must prove that a real Cursor session has the same user-visible and
durable behavior across:

1. Creation and normal multi-turn use.
2. Model, mode, effort, and command selection.
3. Text, tool calls, file changes, questions, permissions, and plan mode.
4. Image input from the phone and image output from Cursor.
5. Navigation, app relaunch, relay reconnect, agent respawn, and bridge restart.
6. Rename, archive, unarchive, deletion, and cleanup.
7. Failure, abort, setup, and account-gate behavior.

The test is successful only when the live event stream, bridge snapshots, and
the rendered iOS session converge. A unit test or a successful CLI response by
itself is not sufficient.

## Coverage Model

Run the layers in this order. Stop and record a blocker when a prerequisite
layer cannot provide a trustworthy environment for the next one.

| Layer | Surface | Required evidence |
|---|---|---|
| L0 | Cursor and ACP package tests | Test output and analyzer result |
| L1 | Real Cursor process through the headless bridge | Bridge log, health/setup response, route snapshots |
| L2 | Relay-connected iOS application | Screenshots or recording plus session IDs |
| L3 | Recovery and persistence | Before/after snapshots across navigation, relaunch, and restart |
| L4 | Cleanup and privacy review | Deleted-session checks and evidence inventory |

### Automated baseline

Run before the live matrix, and rerun after any code fix found during the
matrix:

```sh
cd bridge/sesori_plugin_acp && dart test
cd ../sesori_plugin_cursor && dart test
cd ../sesori_plugin_acp && dart analyze --fatal-infos
cd ../sesori_plugin_cursor && dart analyze --fatal-infos
```

The full bridge workspace may be run when the change or failure crosses plugin
boundaries:

```sh
cd bridge && make analyze && make test
```

The client app is part of the live test. If client code changes while fixing a
finding, run its relevant package tests and analysis before resuming:

```sh
cd client/app && flutter test
cd client/app && flutter analyze
cd ../module_core && dart test && dart analyze
```

## Environment

### Required components

- A macOS host with the repository-pinned Flutter/Dart SDK available.
- A current Cursor CLI that satisfies
  `CursorPluginDescriptor.minVersion` in the checked-in source.
- A Cursor account authenticated for the CLI, or a non-empty
  `CURSOR_API_KEY` supplied only through the process environment.
- A Sesori development account for the selected isolated slot.
- An iOS simulator owned by that slot, running the current app build.
- A disposable project directory that can be read and modified by Cursor.

The checked-in implementation currently defaults to `cursor-agent`. Verify the
actual executable with both `cursor-agent --version` and `agent --version` when
available. If the installed CLI is named `agent`, pass it explicitly with
`--cursor-bin`; do not silently treat the binary-name discrepancy as a test
pass.

### Isolated slot

Claim one unused local slot before starting any process. Keep the same slot for
the bridge, account, debug port, simulator, and data directory for the whole
run. The repository's development slot mapping is:

| Slot `x` | Sesori dev account | Debug port | Bridge data directory | Simulator |
|---|---|---|---|---|
| `1` through `9` | `{x}@sesori.com` | `997{x}` | `~/.local/share/sesori-dev-{x}` | `sesori-dev-{x}` |

Use only the dev account for the claimed slot. Obtain its dev-only password
through the local testing credential source; never put a password or token in
this document, shell history, or captured evidence.

Check ports first and do not reuse an occupied slot:

```sh
lsof -nP -iTCP:9971-9979 -sTCP:LISTEN
```

Use the next free debug port, then start the bridge from `bridge/app` with
debug logging and the slot-owned data directory. Pass `--cursor-bin` and
`--cursor-api-endpoint` only when the test needs an explicit override. Preserve
stdout and stderr in an external evidence directory.

The bridge must remain headless. Do not add a desktop GUI, test-only plugin
allowlist, source changes, or a bypass around relay encryption to make a case
pass.

### Simulator and app

Create or reuse only the simulator assigned to the slot. Build and launch the
app using the slot name, then sign in with the matching Sesori development
account. Confirm all of the following before starting the matrix:

- The app shows the expected signed-in account.
- The app shows the expected bridge and the bridge is online.
- Cursor is available as a selectable backend.
- The selected project is disposable and is not a production checkout.
- The bridge log shows Cursor setup ready, ACP connection, relay registration,
  and phone key exchange.

Do not reset a shared simulator or shut down all simulators. Preserve the
slot-owned simulator between runs unless a clean-install case is explicitly
being tested.

### Fixtures

Create fixtures outside Git, under the disposable project or an external
temporary directory:

- A text file with a known marker for read, edit, and delete checks.
- A small PNG and a small JPEG with known, non-sensitive visual content.
- A malformed or extension-mismatched image for metadata-degradation checks.
- An oversized image for bounded-attachment checks, generated only when the
  test needs it.
- A test prompt set with exact markers, so output can be compared without
  storing the transcript in the repository.

Use the same fixture bytes for live, replay, and restart comparisons. Record
only filename, MIME type, byte count, and a local digest in the report.

## Evidence Protocol

### Three-way comparison

For every user-visible scenario, compare:

1. The normalized live events from the debug server.
2. Bridge route snapshots for messages, status, diffs, questions, permissions,
   and session metadata.
3. The rendered iOS session after the relevant UI action.

Start raw SSE capture before creating or opening a test session:

```sh
curl -N "http://127.0.0.1:${DEBUG_PORT}/global/event" \
  > "${EVIDENCE_DIR}/events.sse"
```

The raw file is SSE, not NDJSON: discard the initial `: ok` comment and blank
lines, remove the `data: ` prefix, and write one JSON payload per line to an
external `${EVIDENCE_DIR}/events.ndjson` normalization file before comparing
events. Keep both files outside the repository.

Use `/global/health` as the readiness check. Use the typed shared request
models, the mobile app, or a small external helper for request bodies; do not
invent inline JSON shapes when a Freezed DTO exists.

Useful debug routes include:

- `GET /global/health`
- `GET /projects` and `GET /sessions`
- `GET /plugin`, `/plugin/setup`, and `/plugin/management`
- `POST /session/create`
- `POST /session/prompt_async`
- `POST /session/messages`
- `GET /session/status`
- `POST /session/diffs`
- `POST /session/questions` and `POST /session/permissions`
- `POST /session/abort`
- `PATCH /session/title`
- `PATCH /session/update/archive`
- `DELETE /session/delete`
- `POST /session/options?refresh=true`
- `POST /global/restart`

The exact HTTP method and body are defined by the route handler and the models
under `shared/sesori_shared/lib/src/models/sesori/`. A `404`, `400`, or `502`
from a route is evidence of a failed scenario unless that status is the
explicit expected result. Treat an expected `409` cleanup rejection or `503`
options-cache unavailability as a scenario result, not as a generic proxy
failure.

### Source-build restart and capture

`POST /global/restart` is valid for a supervised installed bridge. It does not
relaunch the current `dart run bin/bridge.dart` source process. For source-build
testing, stop and relaunch the same command manually, preserving the same slot,
data directory, Cursor binary, and evidence directory. After each replacement
bridge reports healthy and the phone reconnects, start a new raw SSE capture
file for that bridge generation and normalize it separately. A single
`curl -N` process cannot observe events after its bridge socket closes.

### Live ACP trace

The normal bridge log and debug SSE are not a complete ACP stdio trace. For
scenarios that require the exact Cursor response contract, use an external
pass-through wrapper and an explicit `--cursor-bin` override. The wrapper must
forward every stdin/stdout byte unchanged while teeing the newline-delimited
JSON-RPC streams to files outside the repository:

```sh
tee "${EVIDENCE_DIR}/acp-stdin.ndjson" \
  | "${REAL_CURSOR_BINARY}" "$@" \
  | tee "${EVIDENCE_DIR}/acp-stdout.ndjson"
```

Make the wrapper executable, point the bridge at it with `--cursor-bin`, and
verify that only the wrapper's pass-through stdout reaches the bridge. Redact
the captured frames before sharing them; never commit them. Use this procedure
for the live plan-rejection trace and any undocumented extension-shape case.

### Capture rules

For each scenario record externally:

- Matrix ID, timestamp, host/CLI/app versions, and test slot.
- Session ID, project ID, backend/plugin ID, and canonical message/tool IDs.
- The action sequence and a privacy-safe prompt summary.
- Expected result, observed result, and pass/fail/block status.
- Relevant event types and route status codes.
- Screenshot or recording references, stored outside the repository.
- A short failure description with reproduction steps if the scenario fails.

Do not copy raw event payloads into a PR. Redact prompt text, transcript text,
local paths, image content, account identifiers, auth material, and tool output
from the report. Keep the original captures only in an access-controlled
temporary evidence directory until the run is reviewed, then remove them.

## Scenario Matrix

Each row is an independent regression target. `Reset` means delete the test
session and generated files before the next isolated case. `Continue` means
the scenario intentionally builds on the same session.

### Environment and setup

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| ENV-01 | Start the bridge with the supported Cursor CLI and capture health. | Bridge, relay, phone, and Cursor all report ready; the bridge stays headless. | Health, setup, log, app screenshot. Continue. |
| ENV-02 | Start with a missing Cursor binary in an isolated probe. | Cursor is unavailable with an actionable setup state; relay, phone, and other plugins remain usable. | Setup response and log. Reset process. |
| ENV-03 | Probe an older-than-supported CLI. | Cursor is unavailable as outdated; the exact version is not leaked into the user-facing setup response. | Setup response and log. Reset process. |
| ENV-04 | Probe an unrecognized, failing, or hanging `--version`. | Setup becomes unknown within the timeout; the bridge does not hang or crash. | Setup response, process list, log. Reset process. |
| ENV-05 | Run with `CURSOR_API_KEY` and without an interactive CLI status prompt. | Setup is ready without an unnecessary login flow; the key never appears in output. | Setup response and redacted log. Continue. |
| ENV-06 | Run with CLI authentication but no API key. | `status` is used only for setup detection; authenticated status is ready and unauthenticated status is actionable. | Setup response and log. Continue. |
| ENV-07 | Force an ACP handshake failure, unsupported protocol, or authentication rejection in a controlled test environment. | Cursor becomes degraded or setup-blocked without taking down relay, catalog, or other plugins; a later request can retry when recoverable. | Health, setup, log. Reset process. |

### Project and session lifecycle

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| SES-01 | Select Cursor and create a session in the disposable project without a prompt. | A session is created in the selected directory with `pluginId=cursor`, idle status, and no phantom user message. | Session list/detail/status. Continue. |
| SES-02 | Create a session with an exact first prompt. | The accepted prompt appears immediately once, the first assistant turn streams, and the session becomes idle on completion. | SSE, messages, UI. Continue. |
| SES-03 | Create or open a session in a worktree/directory different from bridge launch CWD. | Project and directory attribution use the session directory; activity remains grouped under the stored parent project. | Session/project snapshots and UI. Reset. |
| SES-04 | Enumerate sessions with no history, one history page, multiple pages, and a scoped directory. | Results are deduplicated, sorted, and attributed correctly; an unsupported unfiltered list does not prevent scoped discovery. | Logs, `/sessions`, UI. Continue. |
| SES-05 | Rename a session, navigate away, refresh, relaunch the app, and restart the bridge. | The title persists and the list row keeps a valid timestamp and ordering. | Before/after snapshots and UI. Continue. |
| SES-06 | Archive, unarchive, reopen, and read the same session. | Archive state changes locally without destroying Cursor history; transcript, title, and status remain readable. | Session list/messages/UI. Continue. |
| SES-07 | Query `POST /session/children` for Cursor. | The response is an empty, successful list; no fake children are created. | Route response. Continue. |
| SES-08 | Delete a disposable session with no dedicated worktree. | The session disappears from list, detail, messages, and backend-derived enumeration; a tombstone prevents reappearance after restart. | Expected 404/empty routes and restart snapshot. Reset. |
| SES-09 | Delete a session whose Cursor persistence directory exists, is missing, or is already concurrently removed. | Cleanup is safe and idempotent; no path traversal or unrelated directory deletion occurs. | Redacted log and filesystem metadata outside Git. Reset. |
| SES-10 | Exercise invalid cleanup requests and an explicit worktree/branch cleanup choice where the app exposes it. | Cleanup rejection is typed and actionable; unrelated sessions and files remain intact. | Route response and fixture diff. Reset. |

### Text and turn lifecycle

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| TXT-01 | Send a short exact-response prompt. | The user message is shown immediately and exactly once; assistant text is complete and ordered. | SSE/messages/UI. Continue. |
| TXT-02 | Send a long structured prompt that asks for numbered markers and watch it live. | Deltas never disappear, duplicate, reorder, or render internal Cursor context as authored text. | Event sequence and post-completion digest. Continue. |
| TXT-03 | Send several turns in one session. | Text-to-text ordering and message boundaries remain stable; each turn has one user message. | Live and cold messages. Continue. |
| TXT-04 | Send two prompts quickly to the same session. | Prompts serialize per session; the second is not dispatched until the first settles; busy/idle state spans the whole queue. | Event timestamps and status snapshots. Continue. |
| TXT-05 | Send prompts concurrently to two sessions. | Each response and session status stays attributed to its own session; an id-less Cursor request does not silently cross sessions. | Two event streams and messages. Continue. |
| TXT-06 | Send an attachment-only prompt and an unsupported-only attachment prompt. | Supported content is accepted; a prompt with no mappable content is not enqueued as an empty turn. | Request/event trace and UI. Reset. |
| TXT-07 | Trigger a refusal or prompt failure using a controlled, reproducible prompt/account condition. | The failure is visible as an error, the turn returns idle, and no silent successful assistant message replaces it. | SSE/status/messages/UI. Reset. |
| TXT-08 | Submit text containing non-ASCII characters and inspect live debug SSE. | UTF-8 events remain on the same stream and subsequent events are still delivered. | SSE connection and UI. Reset. |

### Commands and Cursor options

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| CMD-01 | Open a fresh Cursor composer and load options without historical sessions. | Models, modes/agents, effort variants when the account exposes them, and `compact` are available without a throwaway session. | `/session/options`, UI. Continue. |
| CMD-02 | Force-refresh the options catalog and compare it with cached discovery. | Refresh is bounded and isolated; failed forced discovery is reported as failed rather than stale partial success. | Route timings/results and log. Continue. |
| CMD-03 | Use a custom Cursor slash command discovered through `available_commands_update`. | The command appears once, is selectable, and its result is attributed to the current session. | Command catalog event, UI, messages. Continue. |
| CMD-04 | Send `/compact` with arguments. | The phone shows `/compact <args>` while Cursor receives `/summarize <args>`; the transcript is not duplicated. | Prompt event and UI. Continue. |
| CMD-05 | Restart or respawn the Cursor agent, then reload commands. | The command tracker resets and repopulates; stale commands do not remain falsely available. | Logs, options route, UI. Continue. |
| SEL-01 | Create a new session with the default model and mode. | The model/mode reported by `session/new` becomes the new-session default and is displayed consistently. | Options, session defaults, UI. Continue. |
| SEL-02 | Select each available model, mode, and effort variant for separate turns. | Each selected value is sent only when valid and is reflected by the resulting session metadata/behavior. | `session/set_config_option` log/trace and UI. Continue. |
| SEL-03 | Switch models while keeping the same effort variant. | Effort is reapplied using the new model's config ID; a config ID from another model is never reused. | Redacted ACP trace. Continue. |
| SEL-04 | Leave model or variant at default after previously selecting another session's value. | The session's own default is restored; process-global selection does not bleed between sessions. | Two-session trace and UI. Continue. |
| SEL-05 | Disconnect or respawn Cursor after selection, then send another turn. | Model, mode, and effort are reapplied after connection reset instead of being skipped by a stale cache. | Log/trace and UI. Continue. |
| SEL-06 | Request an unknown model, mode, or effort through a controlled debug request. | Unknown values fail closed and are not sent to Cursor; the turn remains diagnosable. | ACP trace and event. Reset. |
| SEL-07 | Use grouped model options and an account catalog with more than the candidate limit. | Grouped values flatten in order and the probe is bounded to the documented candidate count and timeout. | Options response and log. Reset. |

### Tools, permissions, questions, and plan mode

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| TOOL-01 | Ask Cursor to read the fixture file. | One read/tool card has a stable identity, useful output, and completed status. | SSE/messages/UI. Continue. |
| TOOL-02 | Ask Cursor to create, edit, read, and delete a fixture file. | Each file operation has one canonical edit/diff identity; patch/order/status match live and cold history. | Diff route, filesystem, UI. Continue. |
| TOOL-03 | Ask for a command with multiline output. | The command appears once with stable title, output, and terminal state. | SSE/messages/UI. Continue. |
| TOOL-04 | Ask for a command that fails with a known non-zero status. | Live and replay retain error state, useful output, and exit status; failure never becomes completed after reload. | Event/messages/UI. Continue. |
| TOOL-05 | Trigger a permission request for a tool and choose allow once. | The phone shows one pending permission; the reply unblocks the turn and does not escalate to always. | Permissions route, reply event, UI. Continue. |
| TOOL-06 | Trigger a permission request and choose always/reject where Cursor offers those choices. | The selected outcome maps to the correct ACP outcome; a rejected tool leaves a visible, terminal result. | Redacted ACP trace and UI. Continue. |
| TOOL-07 | Trigger a Cursor question with duplicate labels or multiple selection. | Labels are disambiguated for display and the selected answer maps to the correct original option(s). | Questions route, reply event, UI. Continue. |
| TOOL-08 | Reject a Cursor question or abort while it is pending. | The pending prompt clears, the agent is unblocked/cancelled, and no stale card remains after navigation or restart. | Questions/status/UI. Continue. |
| TOOL-09 | Enter Cursor plan mode, accept a plan, and complete the resulting turn. | Plan approval is visible, the accepted response reaches Cursor, and the turn continues normally. | Question event/trace and UI. Continue. |
| TOOL-10 | Enter Cursor plan mode and reject the plan. | Capture the real ACP response contract. Record whether Cursor continues, aborts, or fails; this is an explicit open-risk trace, not an assumed pass. | Full redacted trace, status/messages/UI. Reset. |
| TOOL-11 | Trigger `cursor/update_todos` during a turn. | The phone receives the todo update without an extra visible tool/request card and the turn continues. | SSE/UI. Continue. |
| TOOL-12 | Send an unknown or malformed server request in a controlled harness-only case. | Cursor receives a bounded protocol error or safe cancellation; the approval channel and bridge remain alive. | ACP trace/log. Reset. |

### Images: phone to Cursor and Cursor to phone

The image cases are mandatory. A pass requires both the live event and the
reopened/cold representation to be checked. Do not use private photos or
source-code screenshots.

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| IMG-00 | Create a fresh session whose first prompt contains a small PNG, then repeat with an attachment-only PNG. | `session/create` preserves the first-turn image part and Cursor receives it; the image is not lost because creation and prompt dispatch share one request. | Create request, SSE/messages/UI. Reset. |
| IMG-01 | Select the small PNG from the phone attachment picker and send a prompt asking Cursor to describe it. | The app sends an inline image part, Cursor receives it, and the assistant response demonstrates that the image was available. | Request metadata, UI screenshots, messages. Continue. |
| IMG-02 | Repeat IMG-01 with the JPEG and a text-plus-image prompt. | Text and image preserve their intended order; the image MIME and filename remain correct. | Event/messages/UI. Continue. |
| IMG-03 | Leave the session and reopen it after the image prompt completes. | The prompt contains one expandable attachment with stable metadata and no generated local path leaked as visible text. | Before/after messages and UI. Continue. |
| IMG-04 | Terminate and relaunch the app, then reopen the image prompt. | The attachment remains expandable and the response remains associated with the same turn. | UI recording and messages. Continue. |
| IMG-05 | Restart the bridge and reopen the image prompt. | Inline image bytes/metadata and message ordering match the pre-restart snapshot. | Before/after snapshot and UI. Continue. |
| IMG-06 | Send an attachment-only image prompt and verify Cursor can answer it. | No empty text placeholder is required; the image is the meaningful prompt content. | Request/event/UI. Continue. |
| IMG-07 | Ask Cursor to generate an image using the real Cursor image capability. | The bridge receives and acknowledges `cursor/generate_image`; the generated image appears once as an assistant attachment with stable identity. | SSE, messages, UI. Continue. |
| IMG-08 | Open the generated image from the phone, navigate away, and reopen it. | Viewer controls work and the attachment remains present after navigation. | Screenshots/recording and messages. Continue. |
| IMG-09 | Restart the app and bridge after image generation. | The generated image still has the same user-visible filename/MIME/identity or the documented metadata fallback; no duplicate wrapper shell appears. | Live/cold comparison and UI. Continue. |
| IMG-10 | Exercise generated-image paths: `filePath`, legacy `path`, relative path, invalid bytes, and oversized bytes in controlled fixture/harness cases. | Absolute valid raster files inline within bounds; relative/unreadable files drop safely; invalid or oversized files degrade to basename-only metadata; arbitrary bytes are never promoted by extension. | Redacted logs and typed event snapshots. Reset. |
| IMG-11 | Receive a standard ACP assistant message containing text, image, text, and multiple image candidates when the Cursor build supports it. | Text/image order is preserved, the per-message image count and byte budgets are enforced, and live/replay output matches. | ACP trace, messages/UI. Reset. |
| IMG-12 | Send an unsupported MIME or oversized phone attachment. | The UI or bridge reports a bounded metadata/degradation result; it never hangs, crashes, or silently sends arbitrary bytes. | Request outcome, log, UI. Reset. |

### Navigation, reconnect, restart, and persistence

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| REC-01 | Navigate away and back while a long text turn is active. | Rehydrated state converges with live state and continues receiving updates. | Events/status/UI. Continue. |
| REC-02 | Switch repeatedly between two active Cursor sessions. | Text, tools, images, pending prompts, and status never bleed across session IDs. | Two-session snapshots/UI. Continue. |
| REC-03 | Background and foreground the app during an active tool and during a pending question. | The app reconnects without duplicating messages or losing the pending decision. | Recording, event count, status. Continue. |
| REC-04 | Terminate and relaunch the app during an active turn. | The session reopens with honest status and the completed/active output; no synthetic user message or duplicate tool is introduced. | Cold messages/status/UI. Continue. |
| REC-05 | Stop the source bridge during an active text or tool turn, relaunch the same source command, wait for health and phone reconnect, then start a new SSE capture. | Interrupted work is not left falsely running forever; completed history remains readable and the next turn can respawn/reload Cursor. | Per-generation bridge logs, SSE, status, messages/UI. Continue. |
| REC-06 | Send a prompt immediately after a cold restart without first enumerating sessions. | The stored session directory is primed and Cursor loads/resumes in the correct directory. | ACP cwd trace, filesystem, UI. Continue. |
| REC-07 | Cause a transient resume/load failure, then send another prompt. | Failed transient loads are retried on the next turn; permanently unsupported load is not retried forever. | Logs/trace/status. Reset. |
| REC-08 | Fetch history through the messages route while the session is live. | Replay uses an isolated client and cannot clobber the live connection/configuration; empty history and failed history are distinguishable. | Route response, logs, UI. Continue. |
| REC-09 | Compare live, navigation, app-relaunch, and bridge-restart message order for text, tools, edits, and images. | The same canonical sequence, titles, statuses, attachments, and timestamps are preserved. | Normalized snapshots and UI. Continue. |
| REC-10 | Restart after rename, archive, and delete operations. | Titles and archive state persist; deleted sessions do not reappear from Cursor enumeration or bridge storage. | Before/after routes/UI. Reset. |
| REC-11 | Run two sessions concurrently while one agent process reconnects. | Connection reset state is isolated; the other session remains routable and no selection/turn attribution crosses sessions. | Logs, event stream, two-session snapshots. Reset. |
| REC-12 | Start a second isolated bridge under another slot/account, connect a second phone, and exercise Cursor session creation, options, pending approvals, events, reconnect, and teardown on both bridges. | Bridge IDs, projects, sessions, options, approvals, and SSE events remain isolated; stopping one bridge cannot affect the other bridge or phone. | Two sets of per-generation logs/SSE/snapshots and both UIs. Reset both slots. |

### Abort, gate, and failure recovery

| ID | Scenario and actions | Expected invariant | Evidence / reset |
|---|---|---|---|
| ERR-01 | Abort during a long text response. | The turn becomes terminal/idle, queued prompts are dropped, and late events do not create a second identity. | SSE/status/messages/UI. Reset. |
| ERR-02 | Abort during an active shell/file tool. | The tool has one terminal failed/cancelled representation; late completion updates that identity rather than forking it. | Events/UI/filesystem. Reset. |
| ERR-03 | Abort while permission/question/plan UI is pending. | The phone prompt clears and the agent does not remain blocked after restart. | Pending routes, events, UI. Reset. |
| ERR-04 | Capture Cursor's exact account/plan gate notice, including decorated/case-varied and ordinary-prose controls in a harness where needed. | Exact gate text becomes a visible `cursor_gate` error; ordinary prose containing the phrase remains ordinary text; one gate is not duplicated. | Event/messages/UI. Reset. |
| ERR-05 | Kill Cursor after a request is queued but before dispatch and after dispatch. | A recoverable agent exit respawns and retries safely; an unrecoverable failure is visible and the bridge remains healthy. | Process/log/status/UI. Reset. |
| ERR-06 | Disconnect the relay or phone briefly while a turn completes. | Reconnection restores the session without duplicating durable messages or losing terminal status. | Relay/bridge log, UI, snapshots. Reset. |
| ERR-07 | Submit malformed request data through a controlled debug client. | The bridge returns a typed client error, preserves process health, and does not mutate unrelated sessions. | Status code and health. Reset. |

## Scenario Execution Order

Use this order to maximize signal and avoid contaminating later cases:

1. Run L0 automated tests and verify CLI/setup prerequisites.
2. Claim the slot, start bridge, authenticate, launch the app, and capture the
   initial health/setup/connection evidence.
3. Create one disposable project and run `ENV`, `SES`, `TXT`, `CMD`, and `SEL`
   cases on a baseline session.
4. Run `TOOL` and `IMG` cases while the baseline session has enough history to
   validate replay, then create a second session for concurrency cases.
5. Run navigation, app-relaunch, bridge-restart, and agent-respawn cases. Take
   snapshots before each destructive transition.
6. Run abort and failure cases in fresh disposable sessions. Do not reuse a
   session whose terminal state is part of an earlier assertion.
7. Run the plan-rejection trace and any account-gate case that depends on
   account or model availability. Mark unavailable upstream behavior as
   blocked, not passed.
8. Delete every test session, remove generated files, verify tombstones and
   route responses, stop the bridge cleanly, and review evidence for secrets.

## Pass/Fail Rules

### Pass

A scenario passes only when all applicable checks are true:

- The request is accepted or rejected exactly as expected.
- The live SSE event sequence is valid and correctly attributed.
- Bridge snapshots agree with the live events.
- The iOS UI renders the same user-visible content and state.
- Navigation/relaunch/restart preserves the expected durable behavior.
- No duplicate user message, tool identity, diff, image, or terminal event is
  introduced.
- No private payload data appears in transport diagnostics or the report.

### Fail

Mark the scenario failed for any user-visible mismatch, data loss, wrong
session attribution, false running state, duplicate identity, unexplained
empty history, unsafe cleanup, process hang, or silent error. Include the
smallest reproducing sequence and the first divergent layer.

### Blocked

Use blocked only when the environment cannot exercise the behavior, such as a
Cursor account that has no image-generation capability. Record the exact
missing capability and preserve the scenario for a future run. Do not convert
an unexercised case into pass.

### Release gate

The Cursor plugin is not regression-green when any of these has an unresolved
failure:

- Session creation, text turns, tools, file changes, permissions, questions,
  abort, or restart/replay.
- Phone-to-Cursor image input or Cursor-to-phone generated image output.
- Wrong-session attribution, duplicate identities, or false terminal status.
- Data loss, path traversal, unauthorized file exposure, or auth material in
  logs/transport.

The remaining open plan-mode rejection contract must have a captured result and
an explicit product decision before being described as fully covered.

## Failure Triage

When a scenario fails:

1. Preserve the external evidence and stop cleanup for the affected session.
2. Identify the first divergence among Cursor wire events, bridge events,
   bridge snapshots, and UI state.
3. Check whether the issue is a plugin mapper/reader, shared ACP layer, bridge
   persistence/routing, relay/client transport, or UI projection.
4. Reproduce once from a fresh session before changing code. Do not add a guard
   for a state the real flow cannot produce.
5. If a code fix is required, add or update the smallest meaningful automated
   regression test, run the relevant analyzer/tests, then rerun the affected
   matrix rows and all dependent recovery rows.
6. Record severity, reproduction, impact, cause, fix, result, and residual
   coverage in the dated report.

## Report Template

Copy this outline into `docs/cursor-plugin-stability-report.md` or an external
report for each completed run:

```markdown
# Cursor Plugin Stability Test Report

## Status
## Purpose
## Evidence Method
## Environment
## Automated Verification
## Regression Matrix
## Findings
## Final Live Evidence
## Residual Observations
## Cleanup
## Final Assessment
```

The matrix should retain the stable IDs above and add `Initial`, `Final`, or
`Result` columns. Findings should be privacy-safe and should not paste raw ACP
frames or transcript content.

## Ownership and Maintenance

Update this plan when any of these changes:

- Cursor CLI version floor, executable name, or ACP wire behavior.
- Cursor extension methods, model/catalog shape, or account-gate wording.
- Prompt parts, image limits, attachment rendering, or file-path policy.
- Session persistence, project attribution, replay, restart, or cleanup.
- Bridge routes or the mobile session composer/detail experience.

When changing the plan, verify each new expectation against current code and a
real trace where the ACP shape is undocumented. Keep the plan reusable and put
run-specific results in a dated report.
