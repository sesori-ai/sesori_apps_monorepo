# Instant Session Launch

## Status

- **Plan slug:** `instant-session-launch`
- **Status:** Proposed
- **Architecture review:** rejected 2026-08-31 on three layering/structure
  findings (submission-model location, handoff storage/repository split,
  cross-feature bubble import); all three required changes were applied
  directly below per the review process. The wire contract, bridge emission,
  timeout, presentation reuse, positional release rule, and compatibility
  posture were found compliant as written.
- **PR review corrections (Codex + cubic, 2026-09-01), applied:** launch
  identity carried in the sending variant, handoff threaded through the load
  path's own emissions and preserved across `SessionDetailFailed`/Retry,
  release triggered on the part-update path as well as message envelopes,
  command-launch reconciliation against the bridge queue, and the core-widget
  extraction settled on the verified neutral closure
  (`UserMessageBubble`, `MarkdownMessageImage`, `image_attachment_viewer.dart`)
  so core imports no feature files. A fourth round then corrected the timeout
  above the summed cold budget (180 s), removed the double status rail, and
  rendered the retained bubble on the failed detail branch. A fifth round
  fixed two stale timeout references and replaced command-name queue matching
  with exact identity: the initial command send reuses `launchId` as its
  promptId, so the existing promptId dedupe/swap machinery covers command
  launches with no bespoke rule. A sixth and seventh round settled remaining
  consistency: verification wording, subscription ownership, the required
  nullable handoff parameter, cancel-clears-handoff for command launches, the
  narrowed initial-echo non-goal, and failed-state entries in the step
  scopes.
  The dated-marker request for `launchId` was declined in favor of the shipped
  `promptId` doc-comment posture.
- **Plan date:** 2026-08-31
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `f8fd623953`
- **Delivery:** seven numbered PRs; Step 1 raises this plan before production
  work

This document and `TRACKER.md` are the authority for implementation. The code
and released product behavior remain authoritative where this document becomes
stale.

## Goal

Launching a session against a dormant harness must feel like sending a message,
not like waiting for a service. From the moment Send is pressed:

1. the user immediately sees the normal chat presentation with their own
   message rendered as a sent/pending bubble — never a bare spinner and never
   an empty "No messages yet" screen; and
2. beneath that message, one inline shimmering status line reports what the
   bridge is actually doing — starting the harness, setting up the dedicated
   workspace, creating the session — instead of generic rotating copy, whenever
   the bridge can report it.

The message stays continuously visible through the transition onto the real
session route and until the backend's own transcript echo replaces it, with no
flicker, duplication, or disappearance.

## User Report (2026-08-31)

Creating a session against a dormant plugin (long startup):

1. the create loading state lasts much longer, showing only the generic launch
   spinner/copy; and
2. after arriving on the session screen, the transcript is often empty for a
   while ("No messages yet") until the harness echoes the first message.

Both were confirmed in code; see the findings below.

## Current Behavior And Findings (verified)

### The create request hides everything behind one blocking response

`POST /session/create` carries the first message in `CreateSessionRequest.parts`
and returns the full `Session` only after every launch step completes
synchronously (`bridge/app/lib/src/services/session_creation_service.dart:45-117`):

1. project resolution (`:48`, milliseconds);
2. `ensurePluginRoutable` (`:64`) — an empty `PluginRuntime.use` whose only
   purpose is `_acquire(startIfNeeded: true)`. **This is where a dormant plugin
   starts**: global startup file mutex, single-live-bridge scan,
   `descriptor.ensureRuntime` version probes, then `descriptor.start` — ACP
   harnesses spawn the agent and run `initialize` under a 15 s connect budget,
   managed servers (OpenCode/Codex) spawn and wait for the listener;
3. dedicated worktree preparation (`:68`) — including
   `git fetch` of the base branch with a **30 s timeout on the create critical
   path** (`bridge/app/lib/src/repositories/worktree_repository.dart:146-202`)
   plus `git worktree add` (checkout cost scales with repo size);
4. `SessionRepository.createSession` (`:74`) — backend session creation plus
   first-input acceptance (ACP `session/new` under a 60 s RPC timeout; Claude
   spawns its per-session `claude` CLI child here) and the durable `ses_...`
   binding commit;
5. optional slash-command acceptance (`:96`).

No progress reaches the client during any of this. The only observable signal
is `plugin.management.changed` flipping `runtimeState` to `starting`, which
requires a snapshot re-fetch and carries no launch correlation. Worst-case
bridge budgets (mutex + probes + 15 s connect + 30 s fetch + 60 s `session/new`)
exceed the client's fixed 30 s relay request timeout
(`client/module_core/lib/src/api/client/relay_http_client.dart:15`), so a slow
but *succeeding* dormant launch can be presented as an uncertain failure with
the duplicate-risk warning.

### The launch presentation shows no message

`NewSessionCubit.createSession` emits
`NewSessionPhase.sending(submission)` immediately and awaits the response
(`client/module_core/lib/src/cubits/new_session/new_session_cubit.dart:710-868`).
While sending, `NewSessionScreen` unmounts the composer and fills the body with
a centered `PregoLaunchStatus` (activity indicator + rotating
`newSessionLoadingMessage1..3`)
(`client/app/lib/features/new_session/new_session_screen.dart:447-460`). The
submitted text/attachments — already captured losslessly in
`NewSessionSubmissionSnapshot` for failure restoration — are never rendered.

### Nothing carries the first message onto the detail route

On success the screen calls `replaceRoute(AppRoute.sessionDetail(...))`
(`new_session_screen.dart:412-432`). `SessionDetailCubit` then cold-loads its
snapshot; while loading, `SessionDetailBody` shows the same centered
`PregoLaunchStatus` (`session_detail_body.dart:164-174`), and a loaded-but-empty
transcript renders the plain "No messages yet" text
(`session_detail_loaded_view.dart:87-110`). The user message appears only when
the plugin's transcript echo lands:

- **ACP family** synthesizes the user echo inside `createSession`
  (`bridge/sesori_plugin_acp/lib/src/acp_plugin.dart:910-923`); it is buffered
  until the binding commits and delivered right after `session.created`, so the
  gap is a snapshot race — small but visible.
- **Claude** does not synthesize; the echo arrives only when the per-session
  CLI child replays it (`--replay-user-messages`,
  `claude_event_dispatcher.dart:343-366`), which can lag by seconds.
- **OpenCode** relays its backend's own `message.updated`.

### Existing machinery this plan reuses

- Existing sessions already render optimistic sends: `QueuedSessionSubmission`
  (local `prm_<32hex>` promptId), `PromptSendQueue`, `QueuedMessageBubble` with
  sealed sending/queued/read-only presentations, and stable prompt-row identity
  in `SessionDetailMessageList` (`.plan/completed/bridge-owned-prompt-queue/`).
  The new-session flow bypasses all of it.
- `catalog.import.progress`, `plugin.install.progress`, and
  `plugin.authentication.progress` are in-repo precedents for bridge-owned
  progress events: a service exposes a stream, the orchestrator maps it into
  `SesoriSseEvent` and calls `_enqueueWireEvent`
  (`bridge/app/lib/src/orchestrator.dart:850-880`).
- Relay request routing is concurrent (`relay-request-concurrency` series), so
  SSE events reach the client while `/session/create` is still pending.
- Old clients skip unknown SSE union tags
  (`connection_service.dart` `_isUnknownSseEventType`); old bridges ignore
  unknown JSON request fields. `RelayHttpApiClient.postWithTimeout` already
  supports per-request timeouts (2-minute attachment precedent).

### Relation to prior series

`fast-new-session-launch` (completed 2026-08-20) delivered the immediate
presentation swap and the early canonical response, and explicitly deferred
optimistic first-message rendering, launch progress, and instant first-content.
This plan is that deferred work, scoped to presentation and progress. Its locked
route semantics remain untouched: the URI stays
`/projects/<projectId>/sessions/new` until a durable session returns, duplicate
Send stays blocked, Back keeps the background launch, and every
creation-originated failure still restores the exact submission with the
duplicate-risk warning.

## Design Decisions

- **No pending-session identity.** Perceived instant navigation is achieved by
  presentation: the launch view already replaces the composer in the next
  frame; this plan makes that view *be* the chat. Bridge-issued pending IDs,
  pending rows, idempotency keys, and cancellation remain out of scope exactly
  as `fast-new-session-launch` recorded.
- **Positional release of the optimistic bubble, not promptId correlation.**
  The initial input is accepted before the session becomes visible anywhere, so
  the transcript's first user message is by construction the submitted one.
  Attaching a promptId to the initial echo would require touching every plugin
  (the echo is plugin-synthesized or backend-replayed), and content matching is
  forbidden by the existing queue design. The release rule is therefore: drop
  the launch bubble in the same state emission in which the session's first
  user message with renderable content (`hasRenderableUserContent`) is present.
  Old and new bridges behave identically, so no compatibility split exists.
- **Stages are ephemeral hints, never authoritative state.** They are emitted
  best-effort at step boundaries, carry only a correlation id and a closed
  enum, and have no terminal variant: the create response (or its failure) is
  the terminal signal. A missed or absent event degrades to the existing
  rotating generic copy.
- **Stages are bridge-owned and backend-neutral.** Every reported step
  (plugin start, worktree preparation, backend create) runs in `bridge/app`;
  no plugin package changes and no plugin-interface changes. Harness display
  names come from the client's existing branding, not the wire.
- **Always emit at the boundary, no warm/cold detection.** A warm plugin passes
  `startingPlugin` in milliseconds and the client simply shows the latest
  stage; conditional emission would add runtime-state reads for no user-visible
  gain.
- **The inline status line is launch-scoped.** After the durable response, the
  session exists and the existing busy surfaces (app-bar activity indicator,
  composer stop affordance, streaming parts) are the honest signal. The line is
  not persisted, not a transcript row, and not a `MessagePart`.
- **Create timeout rises to 180 s.** The bridge's own budgets already exceed
  30 s for a dormant launch — and sum to ~130 s worst-case cold, and with live stage feedback a longer wait is
  honest. Failure semantics are unchanged; Back still leaves the launch in the
  background. Old-bridge pairings simply keep rotating generic copy for longer
  before the existing uncertain-failure restore.
- **No analytics.** Consistent with the prior series' explicit exclusion of
  launch analytics/timing telemetry; nothing here answers a new product
  question that existing creation analytics do not.

## Design

### 1. Wire contract (shared)

- `CreateSessionRequest` gains `String? launchId` — a client-generated
  correlation id (`lch_` + 16 secure-random bytes hex, mirroring
  `_generatePromptId`). Old bridges ignore the extra key; when absent (older
  clients) the bridge emits no progress. The field's doc comment states that
  legacy meaning exactly as `SendPromptRequest.promptId` already does ("null
  from clients that predate it; the bridge then emits no progress"). For
  slash-command starts the same id also becomes the initial command send's
  promptId (Design §2), giving the client exact queue/echo identity for the
  launch input. No dated
  compatibility marker is added: absence remains a valid contract for as long
  as any released client omits the field, the same shipped posture as
  `promptId`, and there is no honest non-null default for a correlation id.
- New enum `SessionCreateStage { startingPlugin, preparingWorkspace,
  creatingSession, unknown }` with
  `@JsonKey(unknownEnumValue: SessionCreateStage.unknown)`, so a future stage
  degrades on old clients instead of throwing.
- New `SesoriSseEvent` variant `@FreezedUnionValue("session.create.progress")`
  carrying `{required String launchId, required SessionCreateStage stage}`. It
  is **not** an `@Implements<SesoriSessionEvent>()` variant — no session id
  exists yet. Lockstep mechanical arms in client `module_core`
  (`sse_event.dart` `_extractSessionId` → null, `sse_event_tracker.dart`,
  `SessionDetailCubit._isRelevantGlobalEvent` → false, `session_list_cubit.dart`
  ignore) keep the exhaustive switches compiling; old released clients skip the
  unknown tag.
- Round-trip, omitted-`launchId`, and unknown-stage decode tests beside the
  existing compatibility suites.

### 2. Bridge stage emission

- `SessionCreationService` exposes
  `Stream<SessionCreateProgress>` (`{launchId, stage}` record/class) from one
  broadcast `StreamController`. `_createSession` emits synchronously, only when
  `request.launchId` is non-null:
  - `startingPlugin` immediately before `ensurePluginRoutable` (`:64`);
  - `preparingWorkspace` immediately before `_prepareWorktree` (`:68`), only
    when `request.dedicatedWorktree` (in-place HEAD capture is milliseconds and
    reports nothing);
  - `creatingSession` immediately before `SessionRepository.createSession`
    (`:74`); slash-command acceptance stays under this stage.
- `_maybeSendCommand` passes `promptId: request.launchId` into the initial
  slash-command send when the request carries one (today's generated fallback
  otherwise). The command already flows through the normal promptId-aware send
  path, so this one threaded value gives the client exact queue and echo
  identity for the launch command without any new rule or state.
- A thrown failure simply stops emissions; no terminal or failure stage exists.
- The orchestrator subscribes next to its `catalogImportProgress` listener and
  maps each item to `SesoriSseEvent.sessionCreateProgress` via
  `_enqueueWireEvent`. The controller closes at the end of
  `SessionCreationService.drain()`, inside the existing shutdown ownership.
- Tests: stage order for dedicated and in-place creations; no emission without
  `launchId`; no `preparingWorkspace` for in-place; emissions stop at the
  failing step; drain closes the stream.

### 3. Client launch identity, stage state, and timeout (module_core)

- `NewSessionCubit.createSession` generates the `launchId` per submission and
  threads it through `SessionRepository.createSessionWithMessage` and
  `SessionApi` (`required String launchId`, internal lockstep — no optional
  parameter).
- `NewSessionPhaseSending` gains `required String launchId` and
  `required SessionCreateStage? stage` (stage null until the first event —
  fallback copy). Carrying the identity in the sending variant, not in a
  coordinated nullable cubit field, makes the match exact across retries: a
  resend after failure enters a new sending phase with a fresh `launchId`, so
  a late event from the previous attempt can never update it, and settlement
  discards identity and stage together. The cubit subscribes once to
  `ConnectionService.events`, owned and cancelled in `close()` exactly like
  the existing status subscription; a
  `session.create.progress` event updates `stage` only when the current phase
  is sending with the event's `launchId`. Late, foreign, or post-settlement
  events are ignored by that same match.
- Both create paths in `SessionApi` switch to `postWithTimeout` with a
  create-specific `Duration(seconds: 180)`. The deadline must sit above the
  complete sequential bridge budget, not inside it: a cold dedicated launch can
  legitimately spend up to ~130 s (runtime version probe ~10 s + ACP connect
  15 s + base-branch fetch 30 s + `git worktree add` process budget +
  backend `session/new` 60 s) before smaller Git/database work and optional
  command acceptance, so 180 s covers it with transport margin instead of
  reproducing the uncertain-failure path this change exists to remove.
  `postWithTimeout` currently hardcodes `sensitiveResponse: true`, which would
  null the raw error body out of local create-failure logs; it gains a
  `sensitiveResponse` parameter so the create path keeps its diagnostically
  useful error text while the existing attachment caller stays sensitive.
- Tests: stage updates only for the matching in-flight launch; failure
  restoration and background-leave behavior unchanged; timeout override
  applied on both the plain and attachment create paths.

### 4. First-message handoff to session detail (module_core)

- `queued_session_submission.dart` relocates from `cubits/session_detail/` to
  `foundation/models/composer/`, because the handoff makes it a shared model
  consumed below the cubit layer and by two cubits. Its current importers
  (`prompt_send_queue.dart`, `session_detail_cubit.dart`,
  `session_detail_state.dart`, and the barrel export) update in lockstep. The
  relocated model gains the single owner of local `prm_` id generation (a
  factory replacing the cubit-local `_generatePromptId`), so both cubits mint
  ids through one seam.
- The handoff mirrors the composer-draft split exactly:
  `SessionLaunchHandoffStorage` (Layer 1, `lib/src/api/storage/`) owns the
  single in-memory slot `({String sessionId, QueuedSessionSubmission
  submission})?` with write/read/clear; `SessionLaunchHandoffRepository`
  (Layer 2, `@lazySingleton`) delegates to it and owns the match-then-consume
  rule — `take({required String sessionId})` returns-and-clears only on a
  matching id and is otherwise inert. No persistence, no timers.
- On the same success path that emits `NewSessionCreated` (and only there — a
  background completion after the cubit closed stashes nothing, matching the
  existing background-failure discipline), `NewSessionCubit` maps the
  submission snapshot to a `QueuedSessionSubmission` and stashes it for the
  created session id. Text submissions get a fresh local `prm_` promptId that
  never goes on the wire; command submissions reuse the launch's `launchId` as
  the promptId, matching the id the bridge used for the initial command send.
  Content comes from the snapshot and configuration.
- `SessionDetailCubit` takes the handoff before constructing its initial
  state, and the value then lives only in state:
  - `SessionDetailState.loading` gains `required QueuedSessionSubmission?
    launchSubmission` (required nullable per the repository parameter rule —
    a defaulted parameter would let an ordinary emission silently discard the
    already-consumed handoff), set on the initial state.
    `_loadMessages` preserves the current state's `launchSubmission` in every
    loading emission it makes and passes it into `_buildLoadedState` — the
    constructor-set value must survive the load path's own emissions, or the
    continuity is lost on every successful navigation.
  - `SessionDetailLoaded` gains the same nullable field. Release clears it in
    the same emission that renders its authoritative replacement:
    - text submissions: when the transcript contains a user message with
      renderable content — applied wherever that content can first appear:
      `_buildLoadedState` on snapshots, `_onMessageUpdated` on live envelopes,
      the part-update path for the common empty-envelope-then-
      `message.part.updated` delivery the cubit already accounts for, and
      silent-refresh reconciliation;
    - command submissions carry exact identity instead of a matching rule:
      the bridge sends the initial command through the normal post-create send
      path (Claude exposes it as a bridge-queued prompt before its transcript
      echo), and that send now uses the request's `launchId` as its promptId
      (Design §2). The command handoff bubble therefore uses `launchId` as its
      local promptId, and the existing machinery applies verbatim — the
      local/server dedupe hides the bubble while the queue lists the id, and
      `_releaseDeliveredPrompt` swaps it on the promptId-carrying echo. A
      successful local `cancelBridgeQueuedPrompt` whose promptId equals the
      launch id also clears `launchSubmission` in the same emission — the
      cancelled input will never echo, and the bubble must not resurrect. A
      cancellation issued by another client leaves a stale bubble until
      refresh; accepted residual for that rare cross-client flow. No
      command-name matching exists. Against an old bridge the ids cannot
      match, so the command bubble degrades to the first-renderable-user-
      message rule; a same-named user command queued inside that echo window
      can then release the bubble early, a transient that self-corrects when
      the initial echo lands (accepted residual, old bridges only).
  - `SessionDetailFailed` carries the same nullable field: a failed initial
    load preserves the handoff it already consumed, and Retry threads it back
    into its loading emission — a relay drop between the create response and
    the snapshot fetch must not cost the promised continuity.
  - `showEmptyState` treats a non-null `launchSubmission` as content.
- Accepted residual: if a *different* user message could ever echo first (no
  known plugin does — initial dispatch precedes any later send on every
  current harness), the bubble would blink out and the submitted message would
  still arrive via its own echo; transient, self-correcting, no guard added.

### 5. Launch and detail presentation (app + module_prego)

- New `PregoInlineLaunchStatus` presentation primitive in `module_prego`
  (beside `PregoLaunchStatus`): an inline row with shimmering text, accepting a
  semantics label and an already-localized message list — a single-element list
  renders fixed (stage known), a multi-element list rotates with the existing
  reduced-motion-aware cadence. It knows nothing about sessions or transport.
- The surface extracted to `client/app/lib/core/widgets/` (the documented
  shared-widget location) is exactly the closure the bubble needs and nothing
  more: `queued_message_bubble.dart`; `UserMessageBubble` and its image
  builder `MarkdownMessageImage` moved out of `user_message_card.dart` /
  `text_part_widget.dart`; and `image_attachment_viewer.dart`, which
  `MarkdownMessageImage` invokes for tap-to-view and which already imports
  only packages and `core/` (its other consumers, `text_part_widget.dart` and
  `file_part_widget.dart`, switch to the core import). `UserMessageCard`,
  `AttachmentCollectionWidget`, and the rest of `text_part_widget.dart` stay
  in `features/session_detail/` and import the extracted widgets from core.
  Core widgets import no feature files, and no
  `features/new_session` → `features/session_detail` import is added.
- `NewSessionScreen` sending branch replaces the centered `PregoLaunchStatus`
  with a chat-shaped body: the submission rendered through `QueuedMessageBubble`
  with the new rail-less presentation, and `PregoInlineLaunchStatus` beneath it
  as the single status line. The bubble's existing sending rail is deliberately
  not used here — composing it with the stage line would render two
  simultaneous status rows, and the stage line subsumes its meaning. No cancel
  affordance exists because creation cannot be cancelled. Stage copy is app-owned in
  `app_en.arb`: "Starting {harness}…" (display name from existing client
  branding), "Setting up workspace…", "Creating session…"; a null/unknown
  stage falls back to the existing rotating `newSessionLoadingMessage1..3`.
  Composer stays unmounted; failure remounts it with the restored draft exactly
  as today.
- `QueuedMessageBubble` gains one read-only, rail-less presentation
  (content-only, not outlined) used for the launch submission throughout: on
  the sending view, where `PregoInlineLaunchStatus` is the only status line,
  and after acceptance on the detail route — the later echo swap is then
  visually invisible.
- `SessionDetailBody` loading branch: when `loading.launchSubmission` is
  non-null, render the same chat-shaped pending view (bubble +
  `PregoInlineLaunchStatus` with the generic rotating copy) instead of the
  centered status, preserving visual continuity across the route replacement.
  Ordinary session opens (null handoff) keep the current centered status.
- `SessionDetailBody` failed branch: a non-null `failed.launchSubmission`
  renders the bubble above `SessionDetailErrorView` — retaining the handoff
  data through failure (Design §4) is pointless if the failure screen blanks
  the message until Retry.
- `SessionDetailMessageList` renders `launchSubmission` as the oldest overlay
  row (before queued/sending rows), keyed by its local promptId so the row
  identity is stable across loading/loaded emissions.
- Widget tests: launch view shows the message and stage line in the first
  sending frame; stage text replaces rotation when an event arrives; fallback
  rotation without events; continuity across route replacement; no
  "No messages yet" while the handoff is pending; release swap produces no
  blank or duplicate frame; reduced-motion and semantics coverage; split-view
  and failure-restoration behavior unchanged.

## Failure Semantics

Unchanged from the shipped behavior, restated for completeness:

- Definitive rejection, timeout (now 180 s), and response loss on the
  still-current route restore the exact submission with the duplicate-risk
  warning; the launch bubble and status line are simply replaced by the
  restored composer.
- Back during launch keeps the background launch; no handoff is stashed unless
  `NewSessionCreated` is emitted on the still-open cubit.
- A launch bubble whose echo never arrives stays rendered as the accepted
  message; the turn's failure surfaces through the existing session
  status/error surfaces, and any later refresh that delivers the echo releases
  it.

## Compatibility

- **New client + old bridge:** `launchId` is an ignored unknown key; no
  progress events arrive; the status line keeps the generic rotating copy. The
  chat-shaped launch, handoff, and release rule are entirely client-side and
  work unchanged. The longer create timeout only widens the success window.
  One accepted visual limitation: a Claude command launch exposes its accepted
  command in `bridgeQueuedPrompts` under a bridge-generated id the client
  cannot match, so the handoff bubble and the server queue row render together
  for the seconds-long queue window until dispatch/echo. Cosmetic, transient,
  and self-correcting; per the low-damage compatibility rule it gets no
  reconciliation machinery.
- **Old client + new bridge:** no `launchId` is sent, so the bridge emits no
  progress events; even a stray new event tag would be skipped by the shipped
  decoder. Behavior is unchanged.
- No database migration; no plugin-interface change; no plugin package change;
  `include_if_null: false` keeps the new optional field off the wire when
  absent.

## Non-Goals

- No bridge-issued pending session ID, pending-session row, idempotency key,
  creation cancellation, or automatic resend (unchanged from
  `fast-new-session-launch`).
- No per-plugin sub-stages, no plugin-interface progress surface, no
  `RuntimeProvisionProgress` forwarding, and no percent/measure fields.
- No promptId on the initial text-parts echo and no bridge-side echo
  rewriting. The slash-command start keeps its normal plugin-stamped promptId
  — now fed by `launchId` (Design §2) — which the command handoff relies on.
- No stage persistence, no session-list "launching" placeholder, no desktop
  surface work (the desktop shell cannot create sessions).
- No pre-warming of dormant plugins when the new-session screen opens
  (deliberate speculative process start; possible follow-up if cold-start
  remains a complaint after honest progress ships).
- No change to worktree preparation itself. The 30 s `git fetch` on the create
  critical path is now at least *visible* under `preparingWorkspace`; moving it
  off the critical path changes base-freshness semantics and is a separate
  effort.
- No new analytics events.

## Complexity Budget

New mutable parts, each justified:

1. **Bridge:** one broadcast `StreamController<SessionCreateProgress>` on
   `SessionCreationService` — the feature's delivery seam; no per-launch map,
   registry, or retained state.
2. **Client:** one single in-memory handoff slot, owned by
   `SessionLaunchHandoffStorage` (Layer 1) behind a delegating
   `SessionLaunchHandoffRepository` (Layer 2) — the only way the detail route
   can render the message before the bridge lists it; written iff
   `NewSessionCreated` is emitted, cleared on consume, overwritten by the next
   launch.
3. **Client:** one `ConnectionService.events` subscription in
   `NewSessionCubit`, filtered by the current in-flight `launchId`.

State fields (immutable snapshots, not coordination): `launchId` and `stage`
on `NewSessionPhaseSending`; `launchSubmission` on `SessionDetailLoading`,
`SessionDetailLoaded`, and `SessionDetailFailed`.

Deliberately not added: launch registries, stage ordering guards, terminal
events, retry/timeout machinery for the handoff bubble, echo-correlation state,
persisted anything. If implementation appears to need any of those, stop and
ask before expanding scope.

## Cleanup Assessment

- The centered full-screen `PregoLaunchStatus` usage in `NewSessionScreen`'s
  sending branch and its widget-test expectations are replaced by the
  chat-shaped launch body (Step 5). `PregoLaunchStatus` itself remains in use
  for ordinary session-detail loading.
- `newSessionLoadingMessage1..3` remain as the fallback rotation.
- Two directly caused structural moves ride their feature steps:
  `queued_session_submission.dart` to `foundation/models/composer/` with the
  cubit-local `_generatePromptId` retired into the model's factory (Step 4),
  and `queued_message_bubble.dart` plus the extracted
  `UserMessageBubble`/`MarkdownMessageImage` to `core/widgets/` (Step 5). Both
  are mechanical relocations demanded by the new consumers, not opportunistic
  refactors.
- No obsolete transport shapes, fields, flags, or database artifacts were
  found; nothing else becomes unreachable.

## Delivery Plan

Series slug `instant-session-launch`; every PR titled
`<emoji> [instant-session-launch] <description> [step <x>/7]`.

| Step | Exact PR title | Scope |
|---|---|---|
| 1/7 | `🌱 [instant-session-launch] docs: plan instant session launch [step 1/7]` | This plan and `TRACKER.md`. |
| 2/7 | `🌿 [instant-session-launch] contracts: session create progress wire surface [step 2/7]` | Shared `launchId` field, `SessionCreateStage`, `session.create.progress` variant, codegen, round-trip/unknown-decode tests, lockstep client switch arms. |
| 3/7 | `🌿 [instant-session-launch] bridge: report session create progress stages [step 3/7]` | Progress stream on `SessionCreationService`, three boundary emissions, orchestrator wiring, drain close, tests. |
| 4/7 | `⚙️ [instant-session-launch] client: carry the first message and stages through launch [step 4/7]` | `QueuedSessionSubmission` relocation to `foundation/models/composer/` with single `prm_` id owner, `launchId` generation/threading, 180 s create timeout + non-sensitive `postWithTimeout` option, sending-phase stage state + event subscription, `SessionLaunchHandoffStorage` + `SessionLaunchHandoffRepository`, detail loading/loaded/failed `launchSubmission` + release and cancel-clear rules + empty-state guard, cubit tests. |
| 5/7 | `⚙️ [instant-session-launch] client: render the chat-shaped launch presentation [step 5/7]` | `QueuedMessageBubble` + `UserMessageBubble`/`MarkdownMessageImage` extraction to `core/widgets/`, `PregoInlineLaunchStatus`, chat-shaped sending body, rail-less bubble presentation, detail loading and failed handoff views, message-list launch row, localization, widget tests. |
| 6/7 | `🌱 [instant-session-launch] docs: reconcile launch regression coverage [step 6/7]` | Reconcile affected regression documents; complete the cleanup audit against the implementation. |
| 7/7 | `🌿 [instant-session-launch] verify: run launch coverage and retire the plan [step 7/7]` | Run the recorded level/matrix, record results in `TRACKER.md`, move the plan to `.plan/completed/`. |

Every implementation PR targets well under the 1,500 changed-line soft cap;
Step 2's freezed/codegen churn is the only expected mechanical bulk. Steps 4
and 5 are split exactly so state machinery and presentation review separately.

## Per-Step Verification

- **Step 2:** `shared/sesori_shared` codegen + tests + strict analysis;
  `client/module_core` analysis for the mechanical arms.
- **Step 3:** `bridge/app` creation-service and orchestrator tests +
  `dart analyze --fatal-infos`. Prove ordering, launchId gating, in-place
  omission of `preparingWorkspace`, stop-on-failure, drain close, and the
  initial command send carrying the request's `launchId` as its promptId.
- **Step 4:** `client/module_core` cubit/state/repository tests + analysis.
  Prove stage matching, handoff stash-only-on-emit, release-at-load, release
  on message and part events in one emission, failed-load/Retry preservation,
  command-launch release through the `launchId` promptId across queue dedupe
  and echo swap plus the old-bridge positional fallback, cancel-clear of the
  handoff on a successful matching queue cancellation, reconciliation on
  refresh, timeout override on both create paths, unchanged restoration.
- **Step 5:** `client/module_prego` + `client/app` widget tests + analysis,
  including reduced-motion, semantics, split view, the single-status-line
  sending view, failed-branch bubble rendering, and the no-blank/no-dupe
  swap frames.

CI runs the full matrix; the PR monitor owns failures.

## Regression Documentation And Final Matrix

Affected feature documents (reconciled in Step 6):

- `docs/regression/session-creation-and-options.md` — primary: chat-shaped
  launch, stage line and fallback, handoff visibility and release, 180 s
  timeout.
- `docs/regression/session-turns.md` — inspect; only the overlay-row ordering
  note if the message-list contract wording needs it.
- `docs/regression/navigation-transitions.md` — inspect for the
  launch-to-detail continuity claim.

### Highest required level

**L3 Release.** The delivered claim spans client presentation, navigation,
relay delivery of a new event, and bridge-to-plugin creation timing across
production plugins; automated tests cannot substitute for that boundary.

### Required matrix

- **Client:** one release-target phone platform; narrow and wide/split
  layouts; normal and reduced motion.
- **Bridge:** release-target host; warm and dormant (cold) plugin starts.
- **Stages:** representative coverage (bridge-owned behind the normalized
  boundary): dedicated creation shows the three stages in order; in-place
  skips `preparingWorkspace`; a warm start degenerates gracefully.
- **Plugins:** every plugin registered in the build under test exercises the
  launch flow once; the first-message release rule is additionally scrutinized
  on the three echo families — one ACP harness (synthesized echo), Claude
  (CLI replay echo), OpenCode (backend SSE echo).
- **Compatibility:** current client against an older released bridge (or an
  equivalent wire fixture): generic rotating copy fallback, handoff and
  release still correct, no decode failures.
- **Failure:** definitive rejection and a timeout/response-loss simulation
  still restore the exact submission with the duplicate-risk warning from the
  chat-shaped launch view.

### Measurements

Privacy-safe elapsed observations only (no prompts, titles, paths, or ids),
for one warm and one dormant representative run: Send to message-visible
frame; Send to first stage line; Send to detail route with the message
continuously visible; echo swap without flicker. Acceptance is structural —
the message renders in the first sending frame, the stage line reflects bridge
progress when reported, and no intermediate frame loses the message — not a
wall-clock SLA.

## Risks And Accepted Limits

- Cold starts remain as slow as they are; this plan makes the wait honest and
  keeps the message visible, it does not shorten harness startup. Pre-warming
  is a possible follow-up.
- Stage events are best-effort: an SSE drop or old bridge leaves the generic
  rotating copy. Accepted; the fallback is today's shipped behavior.
- The positional release rule could theoretically drop the bubble on a foreign
  first echo; no current plugin can produce one before the initial dispatch,
  and the outcome self-corrects. Accepted residual, no guard.
- Against an old bridge, a command-launch bubble has no promptId match: the
  server queue row and the handoff bubble render together for the queue
  window, and positional release governs the swap — a same-named user command
  queued inside the echo window can also release the bubble early. Both are
  transient, self-correcting, old-bridge-only visuals. Accepted residuals.
- A 180 s create timeout means a genuinely lost response is detected later
  than today on the launch view. Back remains available throughout, and the
  uncertain-outcome warning semantics are unchanged.
- The launch bubble is rendered from client memory until the echo; a client
  process death during launch loses it exactly as it loses any pre-ACK
  submission today. Accepted, unchanged exposure.

## Expected Result

Pressing Send against a dormant harness immediately shows the normal chat with
the user's message and a live status line — "Starting Grok Build…", "Setting up
workspace…", "Creating session…" — instead of a spinner with generic copy. The
transition onto the real session route keeps the message on screen with no
empty-transcript flash, and the backend echo replaces it invisibly. Old
clients and old bridges keep exactly today's behavior. No database, plugin, or
plugin-interface change is introduced.
