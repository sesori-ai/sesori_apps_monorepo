# Interrupted And Stopped Turns

## Goal

Issue #2618: a bridge killed mid-turn (OOM, SIGKILL) left an omp session that looked idle and stuck. The user decided
(2026-11-15, review page `issue-2618-interrupted-turns/round-1.html`):

1. **Interrupted turns.** When the bridge stops during a turn, the cut-off turn ends with a quiet line
   "Interrupted · Sesori's bridge stopped during this turn" and a Continue button that sends
   "Continue where you left off." as a normal prompt. The session's row in the list says "Interrupted" until the
   user opens the session or sends something. Nothing continues on its own.
2. **Stopped turns.** A user Stop ends the turn with a small grey "Stopped" line on every harness. It is not an error
   and it fades in when the turn ends. It replaces today's red rows and Claude's bubble. After a reload it stays on the
   harnesses that record the stop (Pi, OpenCode, omp, Claude Code, Codex); on Hermes, Cursor, DeepSeek, Grok, Copilot
   and Antigravity it shows only until the transcript is re-read, because they don't record a stop. The Interrupted
   line uses the same visual style.

## Scope

Phase 1 (this plan) delivers both decisions on every harness. Out of scope: automatic continuation (declined in Q1),
push notifications for interruptions, analytics (see D10), and the later-phase bullets at the end.

## Current behaviour (facts this plan relies on)

- Busy state is memory-only (`SessionRepository._busyObservations`); `SessionEventService._observeBusy` is the one
  core seam that sees every busy/idle transition for every plugin. Nothing records an unclean exit; SIGTERM runs
  `interruptActiveWorkForShutdown` and records nothing; replacing a bridge can SIGKILL the old one
  (`bridge_instance_service.dart`). OpenCode 2 on the shared service keeps running a turn after the bridge dies.
- The only crash cleanup is the read-path sweep in `ChatHistoryService` (tools become errors, subtasks cancelled,
  compactions failed `turnEnded`).
- `replaceSessionMessages` drops a row the backend transcript lacks once an import has covered it, so a row the bridge
  synthesizes into chat history survives one re-import and then disappears or moves. Bridge-owned markers therefore
  must not live in the history rows.
- `Message` and `MessagePart` have no `fallbackUnion`: a new role or part type fails a 1.14.0 client's page decode.
  Unknown JSON keys and unknown top-level SSE event types are ignored. New fields on existing variants are safe.
- `MessageError{errorName, errorMessage}` is the error row; the client renders only `errorMessage` in red and never
  reads `errorName`. The bridge uses `errorName` to merge a live notice with its replayed copy.
- Stop today: ACP harnesses ignore the parsed `AcpStopReason.cancelled` (`acp_plugin.dart` `_runTurn`); omp (after
  #2627) replays "Interrupted by user", "Request was aborted" and "Request was aborted." as an `omp_aborted` error;
  Pi emits "Pi response aborted" live and on replay (`stopReason: aborted`, not distinguishable from other aborts);
  OpenCode v1 emits `MessageAbortedError`, v2 an error with `error.type` (abort value unverified) plus a live
  `session.execution.interrupted(reason: user)`; Codex hides `<turn_aborted>` and only finalizes cards (live signal
  `turn/completed` with `status: interrupted`); Claude Code swallows the interrupted turn's result live and replays
  the CLI's `[Request interrupted by user]` / `[Request interrupted by user for tool use]` user record (no `isMeta`,
  one text block) as a user bubble, confirmed live during session-send step 8.
- The client groups turns with the shared `splitPromptTurns`; an error counts as an answer end, so the next prompt
  opens a new turn. The transcript is a reversed list whose end rows (retry error, Working) live in a keyed
  `TranscriptPresenceColumn`; `TranscriptPresence` grows and fades rows in over 200 ms. The compaction part's
  `TranscriptStepRow` in `textSecondary` / `textSm.regular` is the existing quiet grey line.
- Session rows: `SessionTile._statusLabel` shows Waiting, then Retrying. `Session.unseen` is computed bridge-side as
  `activity > max(lastUserMessageAt, lastSeenAt)`; opening a session declares viewing, which the bridge treats as seen.
- Auto-continuation precedent: per-session `session_continuations` row with a sealed outcome. Other open plans are
  claiming `sesori.db` schema versions, so step 5 uses the next free version on `origin/main` when it is implemented.

## Design decisions

### D1. Stopped is a kind of error row, produced by the plugin that knows the stop

`MessageError` gains `kind` (enum `failure` | `stopped`, `unknownEnumValue: failure`,
`@Default(failure)` with a `// COMPATIBILITY 2026-11-15 (v1.14.0)` marker: older bridges omit it and every error they
send is a failure). The plugin interface does not depend on `sesori_shared`, so it gets its own enum
`PluginErrorKind { failure, stopped }` as a required field of `PluginMessage.error`; `PluginMessageMapper` in
`bridge/app` (Layer 2) maps it to `MessageError.kind`. Each plugin marks the stop it can see, live and on replay, so
the per-harness persistence is exactly the decided one:

| Harness | Live | Replay |
|---|---|---|
| ACP base (Hermes, Cursor, DeepSeek, Grok, Copilot, Antigravity, omp) | `cancelled` stop reason of a turn that `abortSession` cancelled emits one stopped row | Nothing (omp: below) |
| omp | ACP base | "Interrupted by user" → stopped; both "Request was aborted" forms stay `omp_aborted` failures |
| Pi | `stopReason: aborted` → stopped | Same |
| OpenCode v1 / v2 | `MessageAbortedError` / v2 abort error type → stopped | Same |
| Codex | `turn/completed` `interrupted` for a turn Sesori interrupted → stopped | rollout `turn_aborted` → stopped |
| Claude Code | interrupted branch of the result handler → stopped | the two `[Request interrupted by user…]` records → stopped instead of a user bubble |

Synthesized rows use `errorMessage: "Stopped"`; native rows keep their text. Only a stop requested through
`abortSession` (Stop, Stop on archive) produces a live stopped row; shutdown's `interruptActiveWork` does not, so a
bridge shutdown never says Stopped live.

A reload must never show two Stopped lines for one stop. `errorName` and `errorMessage` take no part in
`replaceSessionMessages` pairing (they only choose which wording survives), so each synthesized live row needs a real
pairing key with its replay:

- ACP base: no replay exists, so nothing pairs; the row is a live capture that a later re-import drops (the decided
  "until re-read" behaviour).
- omp: the live row and the replayed "Interrupted by user" notice are both id-less halt-notice rows; they pair the way
  Hermes and Cursor halt notices pair today (content-free error in the same visible context). Step 3 proves it.
- Claude Code: the live row carries the id of the CLI's interrupt record when the stream reports it, otherwise the
  replay pairs by the record's timestamp. Step 4 chooses after checking what stream-json echoes.
- Codex: the live row's id derives from the interrupted turn id, which the rollout `turn_aborted` carries, so live and
  replay share the id.

Steps 3 and 4 each add a reload-after-live-stop test asserting exactly one stopped row.

Rejected: bridge-recorded stops from `abortedSessions`. They would persist on every harness, but they duplicate the
native records on five harnesses, need a dedupe rule and durable state, and the user chose the per-harness limitation.
It stays a later-phase option.

### D2. Interrupted is a bridge-owned record outside chat history

Only the bridge can know it died, so bridge core owns the fact, for every harness, with no plugin change. It is a
per-session row in `sesori.db`, never a history row (see the `replaceSessionMessages` fact), and reaches clients on
the `Session` wire.

### D3. Detecting an interrupted turn

- Data owner: `SessionInterruptionDao` and `SessionInterruptionRepository` (with a record model and mapper, as the
  `session_continuation_*` family) own both new tables, in one new `sesori.db` schema version:
  `session_running_turns(sessionId PK, FK cascade, startedAt)` and
  `session_interruptions(sessionId PK, FK cascade, afterMessageId, acknowledged)`. The repository exposes mark
  running, clear running, leftover rows of a plugin started before a time (joined with sessions on `pluginId`), a
  transactional convert-or-adopt, acknowledge, re-anchor and `readMany(sessionIds)`.
- Writer: `RunningTurnListener` (Layer 4, `listeners/`) subscribes to the session event dispatcher's normalized
  events, marks running when a session goes busy or retries (every busy status overwrites the row and re-stamps
  `startedAt`, so it records when this run last saw the turn running) and clears it when it goes idle. Child
  sessions get rows like any other session. It
  tracks its pending writes and drains them on dispose, as `ChatHistoryActivityListener` does. Its `beginShutdown()`
  is a signal-phase shutdown action registered before `interruptActiveWorkForShutdown`, so the idles those interrupts
  produce do not clear rows: a SIGTERM or update restart leaves the row exactly like a SIGKILL. A plugin stop, plugin
  restart or user Stop ends with an idle and clears it. `SessionEventService` is unchanged.
- Resolver: `InterruptedTurnListener` subscribes to the `readyPluginIds` stream and, like the hydration listener,
  acts on every plugin that newly appears in it (each readiness, not only the first per run; repeated resolution is
  idempotent because resolved rows are gone or adopted). It calls `InterruptedTurnService.resolve(pluginId)`, whose
  collaborators are `SessionInterruptionRepository`, a new `SessionRepository.getPluginSessionStatuses(pluginId)`
  (one plugin's statuses keyed by bridge session id, throwing on a failed read, mapped as the aggregate read maps
  backend ids; ready plugins start lazily, so this read starts a ready but idle plugin, and the service calls it
  only for a plugin that has leftover rows), `ChatHistoryService` (the anchor read) and `SessionMutationDispatcher`.
  The service captures the
  bridge run's start time at construction; a leftover row is one with `startedAt` before it.
- Resolution, per leftover row: still busy → adopt (restamp `startedAt` to now; the OpenCode 2 shared-service case);
  idle → convert (below). A failed status read is no evidence the turn ended, so it keeps the plugin's rows; the next
  readiness or bridge run retries. A plugin that never becomes ready keeps its rows for a later run.
- Converting runs as one `ChatHistoryService` per-session queued operation (`ChatHistoryService.convertInterruptedTurn`)
  that reads the newest stored history message and, in the same operation, has the repository write the
  interruption (unacknowledged, anchored to that message, replacing an older one) and delete the running row in one
  transaction. A session with no stored message only loses its running row. `InterruptedTurnService` then emits
  `SessionInterruptionUpdated` (D4).
- Convert and adopt are compare-and-set on the leftover row's `startedAt` as read: marking running upserts the row's
  time, so a turn this run started after the status read has a newer time and the resolution leaves its row alone.
- Re-import replaces stored ids with imported ones (ACP fallback ids differ live and on replay), so
  `ChatHistoryService`, inside the queued replacement that computes the stored→imported mapping, re-anchors the
  session's interruption through the repository. Resolution and the hydration import fire on the same readiness;
  because the anchor read, the interruption write and the replacement share that queue, either order leaves the
  anchor on an id the store holds. A re-anchor that moves the anchor emits `SessionInterruptionUpdated` so clients
  place the line on the new id. A test pauses a conversion between its anchor read and its write while a
  replacement is queued.

### D4. Wire shape and publication

- `Session.interruption: SessionInterruption?` (shared) with `afterMessageId` and `unacknowledged`. Null means no
  interruption; older bridges omit it, which is honest absence, so no compatibility default is needed. Older clients
  ignore the field. It is projected in `SessionViewService.enrichMany` from `SessionInterruptionRepository.readMany`,
  next to the other bridge-owned per-session state, not in the catalog mapper.
- `unacknowledged` is a stored flag, not a clock comparison, so a skewed host clock cannot stick or hide the label.
  `SessionMutationDispatcher.acknowledgeInterruption(sessionId)` is the one route for both the view and send
  triggers: it calls `SessionInterruptionRepository.acknowledge(sessionId)` and, when a row flipped, emits
  `SessionInterruptionUpdated`. The send acknowledgement happens when the bridge accepts the prompt, not when the
  harness echoes it, so a lost echo cannot leave the label up.
- `SessionInterruptionUpdated` is a new `SessionMutationDispatcher` local mutation, the one route for all three
  triggers (resolution, view, send), mapped to an enriched `session.updated` exactly as `continuationUpdated` is.

### D5. Client: the end-of-turn line

- A shared `TurnEndLine` widget (module_app_ui) renders the quiet line: `TranscriptStepRow` look, `textSecondary`,
  `textSm.regular`, the compaction row's spacing. `ErrorMessageCard` renders `kind: stopped` through it as "Stopped".
- Decisions live in `module_core`: a pure `TurnEndCalculator` in `cubits/session_detail/` (beside
  `TranscriptTurnBuilder`) folds the messages, `Session.interruption`, the session status and the queue into a typed
  end-of-turn view on `SessionDetailLoaded`: where the Interrupted line goes (after the last message of the turn
  containing `afterMessageId`, via `splitPromptTurns`; absent when that message is not loaded), which stopped rows
  are suppressed (one line per turn: a turn holding the interruption draws no stopped row, since OpenCode records
  `MessageAbortedError` when a shutdown aborts the turn), and whether Continue is offered. Widgets only render it.
  The client consumes the shared `SessionInterruption` from `Session` directly; there is no client model.
- The interruption closes its turn. A bridge death before any output leaves the prompt unanswered, and
  `splitPromptTurns` would fold the Continue prompt into it, moving the line below the continued reply and offering
  Continue again. `splitPromptTurns` therefore takes the message ids after which a turn has ended (required named
  parameter; the bridge's prompt index passes none), and the calculator passes `afterMessageId`. The calculator tests
  cover an interruption before the first output followed by Continue.
- Motion: both lines enter through `TranscriptPresence`. The live Stopped row takes the place of the folding Working
  row in the same frame, so the rows above hold still. Nothing above the line moves when it appears or when the
  Continue button leaves.

### D6. Continue

The Interrupted line carries a `PregoButtonsSolid` link-hierarchy small "Continue" button, shown only while the
interrupted turn is the latest turn, the session is idle and nothing is queued. It sends
"Continue where you left off." through the composer's `sendMessage` with the composer's current selection, exactly
like a typed prompt. `SessionDetailCubit.continueInterruptedTurn()` owns the prompt text and refuses (with the reason
the
calculator gives) when Continue is no longer allowed. Once the prompt bubble appears the turn is no longer the latest,
so the button folds away with
`TranscriptPresence` while the line stays.

### D7. Session list

`AllSessionsCubit` derives an `interrupted` flag on `AllSessionsRow` (`interruption.unacknowledged` and not
running); `SessionTile._statusLabel` shows "Interrupted" for it, after Waiting and Retrying, in `textSecondary`. Opening
the session (view declaration) or sending clears it through
the bridge's `session.updated` (D4), so every surface clears together.

### D8. Strings

"Stopped", "Interrupted · Sesori's bridge stopped during this turn", "Continue", "Continue where you left off." and
"Interrupted" are the decided strings. Any other user-visible wording is a product question for the parent.

### D9. Compatibility

- New app, old bridge: no `kind` (all failures, today's look) and no `interruption`.
- Old app, new bridge: ignores `kind` and `interruption`. Pi/OpenCode/omp rows look as today; ACP, Claude and Codex
  stops show a red "Stopped" row (Claude's bubble becomes that row). Accepted: honest text, no broken flow.

### D10. Analytics

None in phase 1: crash frequency is a bridge-diagnostics question, and Continue taps would not change a product
decision yet.

## Complexity budget

Persistent: `session_running_turns` (needed to know a turn was in flight across a process death) and
`session_interruptions` (the user-visible fact; one row per session). In memory: the resolver listener's
previously-ready
plugin set (as in the hydration listener), the running-turn listener's pending writes and shutdown flag, and the
bridge run's start time. One wire enum field, one nullable wire
object.

Deliberately not added: pid files, heartbeats or crash markers; bridge-recorded stops; a per-turn interruption
history; reconciling plugin statuses outside first readiness; new message roles or part types; a new SSE event.

### Safeguards and evidence

- Adopting a still-busy leftover: ordinary flow (OpenCode 2 shared service after an OOM kill), observed by the
  parent's investigation.
- Ignoring idles after shutdown began: ordinary flow (systemd stop, bridge update), the issue's own incident.
- Accepted risk: a plugin process that dies mid-turn while the bridge stays up and never reports idle leaves its row
  until the next restart, which then says "Sesori's bridge stopped" for a turn the harness lost. Rare, low damage.
- Accepted risk: a second interruption replaces the first session's older Interrupted line.
- Accepted risk: on OpenCode 2's shared service a turn can finish while the bridge is down; it then reads idle at
  resolution and shows Interrupted with Continue on a completed turn. No harness-neutral signal tells "finished while
  down" from "cut off", and a harness branch in core is not allowed. Rare (bridge death during an OpenCode 2 turn
  that then completes before restart); the user can ignore the button.

## Steps

| Step | Title | Complexity | Depends on |
|---|---|---|---|
| 1 | Raise the plan | 🌱 | |
| 2 | Stopped line: wire kind, client line, Pi and OpenCode | ⚙️ | 1 |
| 3 | Stopped on ACP harnesses and omp | ⚙️ | 2 |
| 4 | Stopped on Claude Code and Codex | ⚙️ | 2 |
| 5 | Bridge records interrupted turns | 🚧 | 1 |
| 6 | Interrupted line, Continue and list label | ⚙️ | 2, 5 |
| 7 | Reconcile regression docs and harness rows | 🌱 | 3, 4, 6 |
| 8 | Verify and retire | 🌿 | 7 |

Steps 2 and 5 touch different files and may be open together; 3 and 4 likewise.

### Step 1: raise the plan

This file and `TRACKER.md`. Docs-only fast path.

### Step 2: Stopped line, wire kind, client line, Pi and OpenCode

Workspaces: `shared/sesori_shared`, `bridge/sesori_plugin_interface`, `bridge/app`, every plugin (existing error
rows pass `failure`), `client/module_core`, `client/module_app_ui`. `MessageError.kind`, `PluginErrorKind` and the
`PluginMessageMapper` mapping; chat-history/merge round-trip; `TurnEndLine` and `ErrorMessageCard` stopped rendering
with the
D5 motion; Pi `aborted` and OpenCode v1/v2 abort errors become stopped (verify the v2 abort `error.type` live).
Tests: model JSON both directions with omission, mapper pass-through, Pi/OpenCode mappers, widget test for the line.
The PR body states, for the release notes, that older apps show a red "Stopped" row for ACP, Claude and Codex stops.
Docs: session-turns stop entry, HARNESS_CAPABILITIES "Stopped turns" rows for Pi and OpenCode. Estimate ~800 lines
with codegen. Architecture implementation review required (wire and plugin-interface contract).

### Step 3: Stopped on ACP harnesses and omp

Workspaces: `bridge/sesori_plugin_acp`, `bridge/sesori_plugin_omp`, docs. ACP base: remember that `abortSession`
cancelled the turn and emit one stopped row when `_runTurn` gets `cancelled`
(not for shutdown interrupts; not when the turn never started). omp: "Interrupted by user" classified as stopped
with the same `errorName` the live row uses so a reload folds them; aborts stay `omp_aborted`. Update the #2627
HARNESS_CAPABILITIES row. Tests in the ACP base and omp mapper, plus an omp reload-after-live-stop test asserting
exactly one stopped row. ~500 lines.

### Step 4: Stopped on Claude Code and Codex

Workspaces: `bridge/sesori_plugin_claude`, `bridge/sesori_plugin_codex`, docs. Claude: map the two interrupt records to
stopped rows in the history mapper and the live stream; emit the live row
from the interrupted branch, folded with the replayed record. Codex: parse rollout `turn_aborted` (and its reason
when present) into a stopped row on replay; emit it live for a turn `abortSession` interrupted, with the id derived from
the turn id. Tests per mapper plus a
reload-after-live-stop test per harness asserting exactly one stopped row. ~600 lines.

### Step 5: bridge records interrupted turns

Workspaces: `shared/sesori_shared` (`SessionInterruption`, `Session.interruption`), `bridge/app`, docs. The next free
`sesori.db` schema version with both tables and its migration snapshot; `SessionInterruptionDao`,
`SessionInterruptionRepository` with record and mapper; `RunningTurnListener` with its signal-phase
`beginShutdown`; `SessionRepository.getPluginSessionStatuses`; `InterruptedTurnService` and
`InterruptedTurnListener`; `ChatHistoryService.convertInterruptedTurn` and re-anchoring in its replacement;
acknowledgement through `SessionMutationDispatcher.acknowledgeInterruption` (view, and send at acceptance); `SessionInterruptionUpdated` and the `enrichMany`
projection. Tests: DAO and repository (convert-or-adopt transaction), service (leftover vs adopted vs failed read
keeping rows vs no stored message), idles after `beginShutdown` ignored, re-anchor after a replacement with changed
ids, a conversion paused between anchor read and write while a replacement is queued, acknowledgement on view and on
send emitting one update, migration. Docs: session-history-and-recovery. ~1,200 lines with Drift output; architecture
implementation review required.

### Step 6: Interrupted line, Continue and list label

Workspaces: `shared/sesori_shared` (`splitPromptTurns` turn-end ids), `bridge/app` (its prompt-index caller),
`client/module_core`, `client/module_app_ui`, docs. `TurnEndCalculator` and its state on `SessionDetailLoaded`,
`SessionDetailCubit.continueInterruptedTurn()`, the line with Continue (D6), supersession of stopped rows (D5),
`SessionTile` label (D7). Calculator and cubit tests without Flutter, including an interruption before the first output
followed by Continue. Simulator recording of the Continue flow and the list label for the PR. Docs:
projects-and-sessions and session-turns. ~700 lines.

### Step 7: reconcile regression docs and harness rows

Make the feature docs and HARNESS_CAPABILITIES match what shipped; remove stale "Stopped shows as an error" text.

### Step 8: verify and retire

Run the verification matrix below, record results in `TRACKER.md`, move the plan to `.plan/completed/`.

## Verification

Highest level: L3 Release, client end to end on the headless iOS simulator slot `sesori-local-testing` assigns, plus
headless bridge for the restart cells. Plugin scope: every supporting production plugin for Stopped, representative
for Interrupted (bridge-owned after a normalized status boundary).

| Cell | Boundary | Plugins |
|---|---|---|
| Stop mid-reply shows grey Stopped, fading in, no jump | Client end to end | Every installed harness; at least omp, Claude Code, Codex, Pi, OpenCode, one other ACP harness |
| Stopped after reload | Client end to end | Pi, OpenCode, omp, Claude Code, Codex stay; ACP harness drops after re-read |
| `kill -9` bridge mid-turn, restart: Interrupted line, list label, Continue sends the prompt, opening clears the label | Client end to end + headless bridge | Representative (omp) |
| SIGTERM bridge mid-turn, restart: Interrupted, no live Stopped | Headless bridge | Representative |
| OpenCode 2 shared service still busy after `kill -9`: no Interrupted | Headless bridge | OpenCode 2, if runnable; otherwise Blocked |

## Cleanup assessment

Directly caused, in the feature PRs: Pi/OpenCode/omp abort rows and Claude's bubble become stopped rows; the #2627
HARNESS_CAPABILITIES note about live omp stops. `FeedbackPromptService._stoppedSessions` stays (it gates feedback
prompts, a different purpose). No other obsolete code found.

## Risks

- Claude live interrupt output is dropped while `process.interrupted` is set; the live row must not be lost or doubled.
- The shutdown fence must be registered before the shutdown interrupts run; step 5 proves it with a test.
- Old apps show a red "Stopped" on ACP, Claude and Codex (D9).

## Later phases (rough)

- Bridge-recorded stops so Stopped survives reloads on ACP harnesses too, if the gap bothers users.
- Distinguish a harness process that died mid-turn while the bridge stayed up (needs its own wording).
- Keep every interruption of a session rather than the latest, if multiple crashes in one session prove common.
