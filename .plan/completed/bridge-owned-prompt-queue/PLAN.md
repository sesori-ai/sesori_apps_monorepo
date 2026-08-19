# Bridge-Owned Prompt Queue

## Status

- **Plan slug:** `bridge-owned-prompt-queue`
- **Status:** Completed 2026-08-19 — all seven steps merged; coverage run
  recorded in `TRACKER.md`
- **Architecture review:** rejected 2026-08-17 on four seam-specification
  clarity findings (read-path repository, cancel chain ownership, cancel
  request model, client layer seams); all four required changes applied
  directly per the review skill's process. The design itself was found
  compliant with the layer rules and directional invariants.
- **Plan date:** 2026-08-17
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `dffad26e4`
- **Delivery:** seven numbered PRs; Step 1 raises this plan before production
  work

This plan and `TRACKER.md` are the authority for implementation. The code and
released product behavior remain authoritative where this document becomes
stale.

## Goal

Sending a prompt to a busy session must be accepted by the bridge near
instantly, survive the phone leaving the screen or locking, stay visible as one
message that transforms `sending → queued → sent` without ever duplicating,
disappearing, or reappearing, and be cancellable while still queued. The same
send contract applies to every harness; Claude is the harness whose plugin
currently violates it and the only one that needs a queue surface today.

User-approved ownership split:

- **Sending** stays client-side and means exactly "the POST to the bridge is in
  flight". With the bridge accepting at enqueue, this becomes sub-second.
- **Queued** becomes bridge-owned state, delivered in the session snapshot and
  over SSE. The client does not retain queued messages.
- **Sent** is the existing transcript message; the queued entry transforms into
  it with an explicit correlation id, never a remove-then-add flicker.

## Observed Defects (2026-08-17, production phone app against Claude session)

1. Sending while a turn runs shows "Sending" for minutes. Root cause:
   `ClaudeSessionService.enqueueTurn`
   (`bridge/sesori_plugin_claude/lib/src/services/claude_session_service.dart:50-88`)
   chains `_runTurn` on `state.tail` and completes the returned `acceptance`
   future only when the turn is dispatched to the CLI — which happens only
   after the previous turn's full outcome (`await dispatch.outcome`,
   `:127`). `POST /session/prompt_async` therefore does not respond until the
   running turn finishes. The client times out at 30 s
   (`client/module_core/lib/src/api/client/relay_http_client.dart:15`).
2. After the timeout the client requeues the submission
   (`SessionDetailCubit._drainQueuedMessages` treats every error as "not
   sent", `session_detail_cubit.dart:1494-1500`), rendering "Queued + Cancel"
   — while the bridge-side request is still alive in the
   `SessionOperationDispatcher` family lane and eventually dispatches. The
   same text then renders twice: the CLI's replayed stdin echo becomes a real
   transcript message and the stale local queue entry stays. A
   silent-refresh-triggered re-drain (`:585`) can re-POST the prompt for a
   genuine duplicate turn.
3. The local queue lives in the screen-scoped cubit
   (`client/app/lib/features/session_detail/session_detail_screen.dart:21-36`);
   leaving the screen closes the cubit and silently drops queued and in-flight
   submissions. The composer draft was already cleared at send.
4. Deadlock hazard: abort, permission replies, and question replies dispatch
   through the same `SessionOperationDispatcher` family lane
   (`bridge/app/lib/src/bridge/services/session_operation_dispatcher.dart:184-200`)
   as the blocked prompt. A permission answer for the running turn can queue
   behind a prompt that itself waits for that turn to finish.

Verified harness facts (Claude CLI 2.1.233 probe, stream-json, plugin's exact
flags): the CLI queues mid-turn stdin user messages (transcript records
`queue-operation` enqueue rows immediately), but the `--replay-user-messages`
echo and the transcript user row appear only when the queued message's own
turn starts; each queued message then runs as its own turn with its own
`result`. So CLI-side queueing cannot provide queued visibility — the bridge
must own the queued representation, and dispatch→echo correlation is strict
FIFO per session.

Contract precedent: ACP already accepts at enqueue
(`bridge/sesori_plugin_acp/lib/src/acp_plugin.dart:1054-1096`), and
`BridgePluginApi.sendCommand` documents "MUST complete once the backend has
accepted" (`bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart:118-127`).
`sendPrompt` lacks that doc line, which is how the Claude implementation
drifted.

## Design

### Wire and interface contracts

- `SendPromptRequest` gains optional `promptId` (client-generated UUID v4,
  also covering command sends, which use the same request). Old bridges ignore
  it; when absent (old clients) the bridge plugin generates one.
- New shared model `QueuedSessionPrompt { id, text?, command?,
  attachmentCount, createdAt }`. `text` is the user-visible text (null for
  attachment-only prompts — never empty string), `command` the bare command
  name for command sends.
- Snapshot fetch mirrors the pending-questions pattern (not the paginated
  messages envelope, which rides every older-page fetch): new
  `POST /session/queued_prompts` with a `SessionIdRequest` body returning
  `QueuedPromptResponse { data: List<QueuedSessionPrompt> }`, fetched in the
  same `SessionDetailLoadService` `.wait` tuple as questions/permissions
  (`session_detail_load_service.dart:112-125`) and degrading to an empty list
  on error exactly like questions do (`:141-148`) — which is also the
  old-bridge (unknown route) path.
- `MessageUser` (shared) and `PluginMessage.user` (interface) gain optional
  `promptId`. It is attached only on the live message event that consumes a
  queued entry; history reads do not reconstruct it.
- New SSE event `session.queued-prompts` carrying `{sessionID, prompts:
  [QueuedSessionPrompt]}` — always the full current list (replace semantics,
  no deltas). Emitted on accept, cancel, dispatch-consume, abort-clear, and
  failure-removal. Old-client tolerance is verified: the shipped decoder
  silently skips unknown SSE union tags
  (`connection_service.dart:563-604`, `_isUnknownSseEventType`).
- New endpoint `POST /session/prompt/cancel` with shared request model
  `CancelQueuedPromptRequest { sessionId, promptId }`. Cancelling an entry
  that no longer exists returns not-found; the client treats that as benign
  (the entry became a message or was already removed).
- `BridgePluginApi`:
  - `sendPrompt` and `sendCommand` gain `required String promptId` (bridge
    generates the fallback before the plugin call, so plugins always receive
    one). Doc comment on `sendPrompt` gains the same accept-not-run-completion
    MUST language as `sendCommand`.
  - New `Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String
    sessionId})` with a default empty implementation, and `Future<bool>
    cancelQueuedPrompt({required String sessionId, required String promptId})`
    with a default `false` — concrete default bodies on the interface
    (precedent: `primeSessionDirectory` no-op, `bridge_plugin.dart:264`), so
    the 23 test fakes and non-queue plugins need no change for these.
  - The `sendPrompt`/`sendCommand` signature change updates every implementer
    in lockstep (no shims): `AcpPlugin` (cursor/hermes/omp inherit it),
    `ClaudePlugin`, `CodexPlugin`, `OpenCodePlugin`, plus the bridge/app test
    fakes. Pi is not a registered plugin yet and is untouched.

### Bridge app

- `SessionPromptService` threads `promptId` (generating the fallback UUID when
  the request omits it) through `SessionRepository.sendPrompt/sendCommand`.
- Read path, pinned: the bridge `SessionRepository` (which already owns the
  binding-resolving prompt seams) gains `getQueuedPrompts({sessionId})` —
  it resolves the bridge-id→backend-id binding, calls
  `BridgePluginApi.getQueuedPrompts`, and owns the
  `PluginQueuedPrompt → QueuedSessionPrompt` mapping in a Layer-2 mapper
  (`repositories/mappers/`). New `GetQueuedPromptsHandler`
  (`POST /session/queued_prompts`), modeled on
  `get_session_questions_handler.dart`, depends on that repository only and
  is registered in the orchestrator handler list
  (`orchestrator.dart:530-595`).
- Cancel path, pinned: `CancelQueuedPromptHandler`
  (`POST /session/prompt/cancel`, modeled on `abort_session_handler.dart`) →
  `SessionPromptService.cancelQueuedPrompt` (the service already owning the
  prompt lane; no new service) →
  `SessionOperationDispatcher.dispatch(operation:
  SessionOperation.cancelQueuedPrompt, body: () =>
  SessionRepository.cancelQueuedPrompt → BridgePluginApi.cancelQueuedPrompt)`.
  New `SessionOperation.cancelQueuedPrompt` enum entry in
  `bridge/app/lib/src/bridge/repositories/models/session_operation.dart`.
- The snapshot and queue fetches are separate requests; a dispatch between
  them can transiently show an entry alongside its message for one refresh
  cycle, self-healed by the very next `session.queued-prompts` event.
  Accepted as bounded transient behavior — no locking machinery. (The live
  `message.updated` info is persisted into bridge chat history including
  `promptId` — `listeners/chat_history_listener.dart:51-65` — so snapshot
  user messages also carry it, letting the client drop a matching queued
  entry even in that window.)
- New SSE event registration points (all compile-time-enforced exhaustive
  switches):
  - interface: new variant in
    `sesori_plugin_interface/lib/src/bridge_sse_event.dart`.
  - bridge/app: `repositories/mappers/session_event_mapper.dart`
    (`backendSessionIds` + the backend-id→bridge-id rewrite arm — the event
    carries a session id and must be translated), `sse/bridge_event_mapper.dart`
    (map to the shared wire variant); non-exhaustive consumers
    (chat-history listener, push notifier, project activity) take the new
    event in their default arms — queued events are deliberately not
    persisted or push-notified.
  - shared: `models/sesori/sesori_sse_event.dart` new
    `@FreezedUnionValue("session.queued-prompts")` variant marked
    `@Implements<SesoriSessionEvent>()` so it reaches
    `ConnectionService.sessionEvents`.
  - client/module_core: `server_connection/models/sse_event.dart`
    (`_extractSessionId`), `session_detail_cubit.dart`
    (`_processSessionEvent`, `_isRelevantGlobalEvent`, `_processGlobalEvent`),
    `session_list_cubit.dart`, `services/sse_event_tracker.dart`.

### Claude plugin (the queue owner)

`ClaudeSessionService` keeps the tail-chain as the execution driver and the
existing `sendTurn`/interrupt mechanics untouched, but:

- `enqueueTurn` (for `sendPrompt`/`sendCommand`) records an explicit queued
  entry `{promptId, displayText/command, attachmentCount, createdAt,
  cancelled, selections}` and **completes acceptance immediately** after
  validation and enqueue. `createSession`'s initial-parts path keeps blocking
  acceptance (its rollback-on-failure semantics depend on it; the
  fast-new-session-launch flow owns that UX).
- Each chained `_runTurn` link checks its entry's `cancelled` flag (in
  addition to the existing generation check) and settles silently when
  cancelled.
- Per-item cancel: mark the entry cancelled, remove it from the queue list,
  emit the queue event. Entries already dispatched return not-found; the
  running turn stays governed by abort/Stop.
- Dedupe: `enqueueTurn` refuses (as success, no-op) a `promptId` already
  queued or present in a per-session set of the last 64 dispatched prompt
  ids — this kills the observed duplicate-turn class when a client retries
  after an uncertain outcome (timeout / relay response lost). The bound
  comfortably covers the retry window: a retry fires on the next
  reconnect/refresh drain while the session-detail cubit is alive, and 64
  interleaved dispatches on one session before that drain is not a plausible
  flow. A retry delayed past eviction would re-enqueue — same exposure as
  today, strictly rarer; accepted residual.
- Dispatch→message correlation, with the no-flicker ordering guarantee
  (message event first, queue event second):
  - Plain prompts: at dispatch, push `promptId` onto a per-session FIFO of
    awaiting-echo ids; when the dispatcher maps the CLI's replayed stdin echo
    to a visible user message (`claude_event_dispatcher.dart:_mapUser`), pop
    and attach `promptId` to `PluginMessage.user`, then remove the entry and
    emit the queue event. The FIFO is sound because dispatch is serialized
    per session and each queued message runs as its own turn (probe-verified).
    The awaiting-echo entry is cleared on turn failure/interrupt so a later
    echo cannot misattribute.
  - Commands: the synthetic user bubble (`_emitVisibleUserMessage`) moves
    from send time to dispatch time, carries the `promptId`, and replaces the
    queued entry in the same ordering (its CLI echo remains dropped as
    today).
- Abort and session delete clear queued entries and emit the queue event
  (empty list) alongside the existing interrupt/cancel-queued behavior.
- A failed dispatch removes the entry, emits the queue event, and keeps the
  existing `BridgeSseSessionError` surface. No per-entry failed state.

### Client (phone app + module_core; desktop has no session surface)

- Submissions get a `promptId` at creation, so the existing
  `failSend`/requeue retry naturally reuses it.
- "Sending" (`PromptSendQueue`) shrinks to its honest meaning: items whose
  POST has not succeeded. Local items render as today ("Sending" while in
  flight, cancellable while parked, e.g. disconnected). Server-queued
  entries render from the new `queuedPrompts` state (snapshot +
  `session.queued-prompts` events) as the queued bubbles with Cancel.
- Client layering, pinned (`api/ → repositories/ → services//cubits/`, no
  skips): `SessionApi.getQueuedPrompts` and `SessionApi.cancelQueuedPrompt`
  (via `RelayHttpApiClient`); delegating methods on the client
  `SessionRepository`; `SessionDetailLoadService` consumes the repository's
  `getQueuedPrompts` in its `.wait` snapshot tuple;
  `SessionDetailCubit.cancelQueuedPrompt(promptId)` calls the repository's
  cancel method (the cubit already consumes this repository for sends).
- A local item whose `promptId` appears in the server list is not rendered
  (covers the SSE-before-ACK window); each state emission shows exactly one
  copy of a message.
- Atomic queued→sent swap: a live `MessageUpdated` whose `MessageUser`
  carries `promptId` upserts the message AND removes the matching queued
  entry in one state emission. The authoritative queue event that follows
  agrees. Because the plugin emits the message before the queue event, no
  frame renders zero copies.
- Abort clears the local outbox as well as (via the bridge) the server queue.
- Uncertain-outcome classification: timeout / `RelayResponseLostException`
  keep the item local and retry with the same `promptId` on the existing
  reconnect/refresh drain triggers; the bridge dedupe makes that safe.
  (Precedent: `PluginRepository`'s uncertain mapping,
  `client/module_core/lib/src/repositories/plugin_repository.dart:44-62`.)

### Behavior on other harnesses

After Step 2, every plugin's `sendPrompt` continues to satisfy or newly
satisfies fast acceptance (ACP/Codex/OpenCode/Pi already do). Their
`getQueuedPrompts` default is empty: OpenCode persists the message upstream
immediately and ACP emits its user echo at acceptance, so their prompts are
already visible instantly as sent messages, which meets the product bar
(queued phase simply never renders). Adopting visible queue entries for ACP's
internal queue is a possible follow-up, not part of this series.

## Non-Goals

- No persistence of the queue across bridge restarts (in-memory, matching
  ACP's accepted-turn semantics; a restart also kills the backend process).
- No per-entry failed state or retry UI; dispatch failure keeps the existing
  session-error surface.
- No change to `createSession` initial-prompt acceptance semantics.
- No ACP/Codex/OpenCode/Pi/OMP/Hermes queue surfaces; they only take the
  mechanical `promptId` parameter.
- No client-side persistence of the pre-ACK outbox; exiting the screen during
  the sub-second send window still drops it (accepted residual risk, stated
  in the regression doc).
- No delta protocol for queue events (full-list replace only).
- No bridge-app-level queue store duplicating plugin state.
- No retry backoff timers beyond the existing reconnect/refresh drain
  triggers.

## Complexity Budget

New mutable parts, each justified:

1. Claude service per-session queued-entry list (+`cancelled` flags) — the
   feature itself: cancellable, queryable queue. Replaces opaque closure
   state in the existing tail chain.
2. Claude per-session bounded recently-dispatched `promptId` set — kills the
   observed duplicate-send failure class; consulted only on enqueue.
3. Claude dispatcher per-session awaiting-echo FIFO — the id-stable
   queued→sent transform, the core UX requirement.
4. Client `queuedPrompts` list in `SessionDetailLoaded` — server-derived,
   replaced wholesale per event.

Deliberately not added: everything in Non-Goals, plus snapshot-composition
locking (bounded self-healing transient accepted instead).

## Compatibility

Public-release baselines (older public apps/bridges) require graceful wire
degradation; internal builds do not.

- New client + old bridge: `promptId` ignored, no queue snapshot field, no
  queue events → client keeps its local rendering; acceptance stays slow
  (old blocking bridge) and the 30 s timeout path behaves as shipped today.
  No new claims are made; behavior is unchanged, not broken.
- Old client + new bridge: fast ACK improves the old client immediately (its
  "Sending" resolves in sub-seconds; its local "Queued" phase disappears
  almost instantly). It ignores the new SSE event (verified: unknown union
  tags are skipped silently, `connection_service.dart:563-604`) and never
  calls the new endpoints, so the queued phase is simply invisible until
  dispatch — strictly better than today's behavior, no breakage.
- `include_if_null: false` keeps all new optional fields off the wire when
  absent.

## Implementation Steps

Series slug `bridge-owned-prompt-queue`; every PR titled
`<emoji> [bridge-owned-prompt-queue] <description> [step <x>/7]`.

1. 🌱 **docs: raise the bridge-owned prompt queue plan** — this document and
   `TRACKER.md` under `.plan/active/bridge-owned-prompt-queue/`.
2. ⚙️ **contracts: prompt ids and queued-prompt wire surface** — shared
   models (`SendPromptRequest.promptId`, `QueuedSessionPrompt` +
   `QueuedPromptResponse`, `MessageUser.promptId`, new SSE event variant),
   plus `CancelQueuedPromptRequest`, interface models/methods
   (`PluginMessage.user.promptId`,
   `PluginQueuedPrompt`, `BridgeSseEvent` variant, `sendPrompt`/`sendCommand`
   signatures + doc contract, `getQueuedPrompts`/`cancelQueuedPrompt`
   interface-level defaults), lockstep mechanical updates in `AcpPlugin`,
   `ClaudePlugin`, `CodexPlugin`, `OpenCodePlugin`, the ~13 `Message.user`/
   `PluginMessage.user` construction sites (repo rule: `required` nullable
   params, no defaults), and the bridge/app test fakes; codegen; JSON
   round-trip tests. Expected overage risk: generated freezed/g.dart churn
   plus fake updates; acceptable, mostly generated/mechanical.
3. ⚙️ **bridge: route and relay the queued-prompt surface** — promptId
   threading with fallback generation in `SessionPromptService`;
   `SessionRepository.getQueuedPrompts`/`cancelQueuedPrompt` with the
   Layer-2 `PluginQueuedPrompt → QueuedSessionPrompt` mapper;
   `GetQueuedPromptsHandler` and `CancelQueuedPromptHandler` +
   orchestrator registration; `SessionPromptService.cancelQueuedPrompt`
   dispatching `SessionOperation.cancelQueuedPrompt`; session-event-mapper
   and bridge-event-mapper arms for the new event; handler/service tests.
4. 🚧 **claude: accept prompts at enqueue and own the queue** — the
   `ClaudeSessionService` rework, per-item cancel, dedupe set, awaiting-echo
   promptId attachment with message-before-queue-event ordering, command
   synthetic move to dispatch time, abort/delete/failure clearing, service +
   dispatcher + plugin tests.
5. 🚧 **client: render the bridge queue and transform states seamlessly** —
   promptId on submissions; `SessionApi` + client `SessionRepository`
   methods for the two new endpoints; `queuedPrompts` state from the load
   service snapshot tuple + SSE; server-queued bubble rendering with the
   cubit's repository-backed cancel; local/server dedupe guard; atomic
   promptId swap; abort outbox clearing; uncertain-outcome retry
   classification; cubit + widget tests.
6. 🌿 **docs: reconcile session-turns regression coverage** — rewrite the
   queued-send required behavior in `docs/regression/session-turns.md`
   (bridge-owned queue, no-flicker transform, cancel, multi-client/exit
   visibility, removal of the cubit-lifetime limitation), add the
   permission-reply-not-blocked-behind-prompt signal to
   `docs/regression/questions-and-permissions.md`.
7. ⚙️ **verify: run recorded regression coverage and retire the plan** — run
   the matrix below, record results in `TRACKER.md`, move the plan to
   `.plan/completed/bridge-owned-prompt-queue/`.

## Verification

- Per-step: owning-package tests + analyzer for touched packages; CI runs the
  full matrix.
- Regression documents affected: `session-turns.md` (primary),
  `questions-and-permissions.md` (lane-unblocking signal).
- Recorded coverage for Step 7: **session-turns L4**, boundaries:
  - Automated: Claude service/dispatcher queue units, client cubit swap
    logic, JSON round-trips.
  - Live plugin (Claude): accept-while-busy latency, FIFO dispatch, per-item
    cancel, abort clearing, dedupe on repeated promptId, permission reply
    while a prompt is queued (deadlock regression).
  - Client end to end (phone, Claude): steer a busy session — instant
    sending→queued, exit/re-enter mid-queue, lock/unlock, queued→sent
    transform with no duplicate/disappearance, cancel from the bubble.
    Uses the global `sesori-local-testing` skill.
  - Relay integration: second client observes the same queue; disconnect
    during send retries safely (no duplicate turn).
  - Other plugins: existing automated suites for the mechanical signature
    change; one live representative send (OpenCode or ACP) to confirm
    no-regression.
- Matrix reductions require explicit user acceptance recorded here before
  retirement.
- **Recorded reduction (accepted by the user via this retirement PR):** the
  step 7 run did not separately exercise a second simultaneous client
  observing the queue, nor a scripted disconnect-mid-send retry. Evidence
  standing in: the idempotent-retry contract is unit-pinned and was exercised
  live (duplicate `promptId` produced no second turn), and queue events ride
  the same SSE fan-out every other session event already proves multi-client.
  All other recorded boundaries ran in full — see `TRACKER.md`.

## Cleanup Assessment

- Client: the local "Queued + Cancel" presentation of server-accepted items
  disappears with the server queue rendering; `PromptSendQueue` stays as the
  in-flight outbox. Included in Step 5.
- Regression doc: the "prompt queue is in memory and owned by session detail"
  known limitation is retired in Step 6.
- No other obsolete fields, flags, or transport shapes were found; the 30 s
  relay timeout stays as the guard for genuinely lost responses.

## Risks And Accepted Trade-offs

- Acceptance-semantics reversal for `sendPrompt` AND `sendCommand` on busy
  sessions: the ACK now precedes backend dispatch, so a prompt or command can
  return success and later fail at dispatch. That failure surfaces as queue
  removal plus the existing `BridgeSseSessionError` — no per-entry failed
  state. This is a deliberate trade-off for instant steering acceptance and
  matches ACP's shipped semantics ("the send was already accepted, so a dead
  agent must surface as a failed turn, not a silent drop"). Step 4
  implements and tests it as such.
- Queue lost on bridge restart (in-memory): accepted, matches ACP acceptance
  semantics; the backend process dies with the bridge anyway.
- Snapshot pair (messages, queue) is not atomic: bounded one-cycle transient,
  self-healed by the next queue event.
- Pre-ACK exit still drops a sub-second-old submission: accepted residual
  risk, documented.
- Old-bridge pairing keeps today's slow-path behavior: accepted, unchanged.
- Claude echo correlation depends on serialized dispatch + own-turn-per-
  message (probe-verified on CLI 2.1.233; the plugin already pins its
  protocol expectations to observed CLI behavior in
  `.plan/completed/claude-code-plugin/PROTOCOL.md`).
