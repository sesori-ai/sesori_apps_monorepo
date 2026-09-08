# Harness-unavailable chats

## Goal and scope

Make an existing chat non-interactive whenever its owning harness is known to
be unusable, with an explicit reason and a route to recovery. Prevent a refused
send from masquerading as queued work or disappearing during the ordinary
chat → Harness Settings → chat recovery journey.

Applies to mobile and desktop and every registered production harness through
backend-neutral management metadata. This is a plan-only change; implementation
has not started. The fixed six-PR series is below.

### User report

Claude Code returned an expired-auth error. Local login failed; restarting the
harness put setup into `authenticationRequired`. An existing chat still allowed
sending and displayed `Queued`. After successful authentication and setup
refresh, returning to the chat lost that apparent queued message.

### Code-grounded findings

- `PluginSetupMetadata` already reports `ready`, `runtimeMissing`,
  `authenticationRequired`, `unavailable`, `notInspected`, and `unknown`.
  `PluginManagementMetadata` adds runtime state, capability declarations and
  recovery hints. No per-session persisted availability field is needed.
- `PluginManagementService.snapshots` already owns connection/bridge identity
  fencing, management-change SSE refresh and publication. Chats do not consume
  it. Use this owner rather than adding polling or a second management cache.
- `SessionDetailCubit.sendMessage` checks archive and attachment constraints,
  but not harness availability. `_drainQueuedMessages` gates on connection,
  archive and submission constraints; a generic error calls `failSend()` and
  only logs. `PromptSendQueue` then presents it as a pending local submission.
- `PromptSendQueue` belongs to the cubit. Its unaccepted submissions do not
  survive disposal. This is a code-supported explanation for the report, not
  a claim that the user's exact send/refresh ordering has been reproduced.
- `PromptInput._submitComposer` invokes a void callback and immediately clears
  text, attachments and staged command. A cubit-only early return would still
  discard authored input unless the handoff contract changes.
- Shared `SessionDetailBody` only chooses read-only presentation for route
  read-only mode or archived sessions. Question/permission modal predicates
  check pending state and archive, not harness usability.
- `PluginRuntime._acquire` already rejects disabled/setup-blocked/transitioning
  or unstartable harnesses before calling their API. Its generic 503 is not
  distinguishable from other unavailable/generation/transport failures by a
  client without parsing prose. Do not infer non-acceptance from every 503.
- Session metadata is catalog-backed, but messages call the owning plugin via
  `SessionRepository.getSessionMessages`. A cold open can therefore fail to
  load history while the harness is blocked. An already loaded transcript can
  remain visible; this feature must not promise offline transcript storage.
- `SessionDetailLoadService.reload` can fail because options are unavailable,
  even when metadata/history are usable. Interactive catalogs must not prevent
  a known-blocked chat from rendering its read-only state.
- Existing draft storage is process-local (`ComposerDraftStorage`), currently
  text/voice spans only. Existing accepted-prompt parking and idempotent retry
  logic must remain intact (history: #966, #971, #1271).

## Product behavior

### Availability policy

Compute one immutable, sealed client-domain availability value from the current
management result plus the session's actual plugin id. Put the pure mapping in
`module_core` (a calculator), not in widgets or individual plugins. Keep archive
and route read-only restrictions independent; recovery never overrides them.

| Current evidence | Chat behavior / primary explanation |
|---|---|
| Ready setup + dormant, starting, active or degraded runtime | Interactive. These are routable/on-demand or recoverable states, not evidence that setup is broken. Preserve normal busy queuing and startup. |
| Runtime disabled | Read-only: “Harness is disabled.” |
| Authentication-required setup | Read-only: “Sign in to [harness] to continue.” |
| Runtime missing | Read-only: “[Harness] is not installed or its configured runtime is unavailable.” Use the provided safe hint for version/path details. |
| Setup unavailable, or terminal runtime failed | Read-only: “[Harness] is unavailable.” Include safe setup/management recovery guidance. |
| Stopping | Temporarily read-only: “[Harness] is stopping.” |
| Not inspected, unknown setup/runtime, unresolved session plugin, missing entry in a supported snapshot | Read-only with honest checking/unknown/not-available guidance; never invent an auth diagnosis or substitute the default harness. |
| Initial management load or first-load failure | Checking or unable-to-check state, respectively, with refresh guidance. Do not label an error as loading forever. |
| A retained supported snapshot with a refresh error | Keep its last-known decision, show that status could not be refreshed. Existing bridge admission remains authoritative. No new freshness timeout. |
| Bridge without the management endpoint | Explicit “Update bridge to check harness availability” limitation. Preserve existing interaction semantics for that supported production compatibility path, rather than disabling every old bridge permanently. |

Disabled takes precedence over setup; a non-ready setup reason takes precedence
over a generic blocked runtime. Unknown/inconsistent evidence fails closed on
management-capable bridges. Connectivity retains its own indication and existing
offline-staging semantics: a disconnect is not “authentication required.” Never
reuse readiness from a different connection/bridge. A previously known harness
block must not be bypassed by going offline; resolving it needs fresh evidence.

### Read-only surface and recovery

- Retain transcript scrolling, selection/copy, history pagination when available,
  navigation and child-history browsing. Do not cover the transcript with a
  gesture-blocking overlay or turn it into a fake empty conversation.
- Replace active input with a persistent, accessible notice naming the harness,
  reason and `Open Harness Settings` action. Reuse existing settings controls
  and authentication/install/refresh capabilities; do not launch login, install,
  or a browser automatically. Add a refresh/retry action for unknown/load failure.
- Disable typed/paste/drop/voice submission, attachment picking, slash commands,
  agent/model/variant changes, stop and remote queued-prompt cancellation while
  blocked. Question/permission responses are disabled too; dismiss an open
  response dialog without answering when the block arrives. Keep pending data
  until an authoritative refresh settles it.
- Navigation, copying and removing a **local unsent** item remain possible;
  those are recovery actions, not interaction with the harness. Do not block
  unrelated bridge-owned list management such as deleting an unreachable
  session or settings operations.
- If history has never loaded, show a metadata-backed unavailable chat shell
  with the same reason/action and an honest “History unavailable until the
  harness is restored” state. Do not cache transcripts or fabricate messages.
- Once fresh management status allows interaction, refresh required history,
  options and pending interactions through existing load paths. Restore input
  only when its actual prerequisites are available; do not require reopening
  the route. Unrelated harness changes must not reload this chat.

### Submission ownership and recovery

1. Guard both new submissions and queue draining in the cubit, using the same
   decision as presentation. Guard other chat mutation intents there as well,
   so keyboard actions and already-open dialogs cannot bypass the view.
2. Give the composer callback an explicit local handoff result: retained by
   caller versus taken by the session. Clear input only after ownership was
   accepted. This acknowledges **local ownership**, not backend acceptance;
   normal optimistic sends and busy queues must remain fast. Update all
   in-repository `PromptInput` consumers together, including new-session flows.
3. A setup block affecting definitely unsubmitted pending items, or a typed
   pre-dispatch refusal, converts those items to visible `Not sent — harness
   unavailable` recovery items. They are not queued and cannot auto-drain after
   login. Preserve text, command, selection, input mode and attachments; allow
   explicit resend after recovery and explicit local removal.
4. Retain those recovery items across the settings round trip in the existing
   process-local composer storage boundary. Extend its session entry with an
   immutable composer payload and immutable unsent recovery items, keeping one
   stored owner instead of parallel copies in a new outbox. Repository APIs own
   updates; cubit/UI project the stored values. Do not overwrite a newer draft
   when a rejected send is retained. Save staged attachment/command content at
   this boundary before disabling/unmounting the composer. Reuse attachment
   size limits; clear removed/sent items and normal session cleanup.
5. Keep a currently in-flight or accepted submission separate: loss of a response
   does not prove it was rejected. Existing stable ids, bridge-owned queue
   events, accepted parking and history reconciliation remain authoritative.
   A blocked notice must not relabel accepted work as definitely “not sent,”
   manufacture success, discard it, or blindly replay it after recovery.
   Transport uncertainty retains its existing handling; no new durable retry
   engine or acceptance reconciliation is part of this feature.
6. Process termination still loses process-local drafts/recovery items. This
   plan fixes the navigation/recovery loss, not durable cross-restart outboxes.
   Already accepted prompts removed by an actual backend restart are governed
   by that plugin's existing queue/history contract, not recreated by this UI.

### Detectability boundary

React to authoritative setup/runtime information, including restart, setup
refresh and management changes initiated by another surface. Request a
management refresh on a definite admission refusal. Do not parse assistant
error text or assume every provider auth failure invalidates the whole harness.
A backend can discover expired credentials only on a turn despite a ready
probe; retain its visible terminal error and provide settings access. Continuous
credential validity, credential watchers and new per-plugin auth classifiers
are not part of this plan. Record verified inspection limitations in
`docs/HARNESS_CAPABILITIES.md`, without promising stronger detection than a
harness supports.

## Concrete ownership and contracts

Paths below are relative to the repository root. New type names are proposed;
implementation may improve a name without changing its owner or behavior.

| Workspace | New / modified ownership |
|---|---|
| `bridge/app` | New `lib/src/runtime/plugin_admission_exception.dart`: `PluginAdmissionException`. Modify `runtime/plugin_runtime.dart` only at the pre-acquisition branches below. New `routing/plugin_admission_response_builder.dart`: a stateless `PluginAdmissionResponseBuilder` used by the existing catches in `routing/request_handler.dart` and `routing/request_router.dart`. |
| `shared/sesori_shared` | New `lib/src/models/sesori/plugin_admission_rejection.dart`: `PluginAdmissionRejection`, `PluginAdmissionRejectionCode`, `PluginAdmissionRejectionReason`; export through `lib/sesori_shared.dart`, regenerate Freezed/JSON. |
| `client/module_core` | New `lib/src/foundation/models/session_interaction_availability.dart` and `lib/src/services/session_interaction_availability_calculator.dart`. Modify `services/session_detail_load_service.dart`, `cubits/session_detail/session_detail_{cubit,state}.dart`, `repositories/session_repository.dart`, composer foundation models/storage/repository, and `di/cubit_composition.dart`. Register calculator in core DI; shared `createSessionDetailCubit` injects it and existing management service into the cubit alone. The stateless load service receives resolved context/projection as method inputs; no cubit-to-cubit dependency. |
| `client/module_app_ui` | Modify `features/session_detail/widgets/{prompt_input,session_detail_body,session_detail_loaded_view,session_detail_composer_controls}.dart`, `session_detail_presentation_scope.dart`, and `features/new_session/new_session_view.dart` under `lib/src/`. New `session_harness_unavailable_notice.dart` in the same shared widget directory; shared localization owns copy. |
| `client/app` | Modify `lib/features/session_detail/session_detail_screen.dart` and its presentation-scope wiring for settings navigation; shared dependency composition stays in module_core. Tests only beyond shell wiring. |
| `client/desktop` | Modify `lib/features/sessions/desktop_session_detail_screen.dart` similarly. No desktop-only availability policy or new desktop-core owner. |

### Exact admission boundary (step 2)

`PluginAdmissionException` extends `PluginOperationException` so existing
repository `isUnavailable` handling still works. Its constructor uses required
named `pluginId`, `operation` and `reason`, with status 503. It is thrown directly,
not manufactured by translating an arbitrary caught exception.

Only replace these explicit `_acquire` rejections: access gate not enabled or
`!startAllowed` → `notAvailable`; `_blocksAcquisition(slot)` before or after
`_ensureStarted` → `transitioning`; final null plugin/generation or non-routable
slot → `notRunning`. These precede handing a lease/API to the requested operation.
Leave shutdown checks, `_requireOperationSlot` errors, exceptions thrown by
startup, generation fencing, and errors from the plugin body unchanged. This is
an operation-admission signal, not a claim that startup did no work.

The response is HTTP 503 JSON with exactly `code: "pluginAdmissionRejected"`,
`pluginId: string`, and `reason: "notAvailable" | "transitioning" | "notRunning"`.
The code and reason are enums with explicit unknown decoding; there is no
`accepted` boolean, raw error text or optional reason. Recognized code plus a
matching plugin id proves this operation was not dispatched even if the reason
is newer/unknown. Unknown code or malformed/unstructured JSON is an ordinary
unclassified failure. Safe detailed UX comes from management, not this body.
The routing response builder owns only serialization into `RelayResponse`; both
existing catch boundaries catch this subclass before the generic exception and
call the same builder. It is not a repository/domain mapper. The runtime remains the sole admission-policy owner. No repository may
catch this signal and silently retry a prompt as a different operation.

### Availability projection and load order (step 3)

`SessionInteractionAvailabilityCalculator.resolve` takes required named
`pluginId: String?`, `management: PluginManagementLoadResult?`,
`connected: bool`, and `previous: SessionInteractionAvailability`. No constructor
state or hidden I/O. The sealed result has:

- `allowed`: verified routable setup/runtime;
- `legacyUnverified`: endpoint explicitly unsupported, with update guidance;
- `checking`: no current evidence yet;
- `blocked`: a required closed `SessionInteractionBlockReason` plus nullable
  display name/action hint (absence is meaningful), never nullable state flags.
  Reasons are disabled, authenticationRequired, runtimeMissing, unavailable,
  stopping, notInspected, unknownStatus, missingHarness, unresolvedHarness and
  checkFailed. Refresh errors on an otherwise supported snapshot remain its
  existing load-result metadata, not another mutable availability cache.

Resolution order while connected: unsupported endpoint → legacyUnverified;
loading/no snapshot → checking; load failure → checkFailed; supported snapshot
with unresolved id → unresolvedHarness; absent exact entry → missingHarness;
disabled runtime → disabled; non-ready setup → its specific reason (unknown and
not-inspected remain distinct); ready setup + routable runtime → allowed;
stopping → stopping; failed/blocked → unavailable; unknown runtime → unknownStatus.
A supported snapshot's `refreshError` does not change that last-known decision.
On disconnect, retain a prior block/checking decision; a prior allowed or legacy
state permits only the existing offline staging (the connection gate still
prevents dispatch). On reconnect, reset to checking until the management owner
publishes evidence for that connection. Never carry a positive result across a
reconnect, and never replace a prior block with permission to stage offline.
The cubit's existing connection-generation boundary scopes the projection; no
bridge-id map or extra generation counter is added.

The cubit is the sole coordinator, owning one subscription to management
snapshots and computing its session's result from its previous state. It requests
the existing coalesced `refresh()` on initial load, explicit retry or typed
admission refusal, not on every message/SSE event. Store a single immutable
`SessionInteractionProjection` in session state: `availability` plus nullable
`managementRefreshError: ApiError?` derived from the retained supported result.
Both loaded and unavailable views consume that projection; the UI renders only
generic refresh-failed guidance, never the error payload. The calculator still
owns only pure transformation and has no subscription/cache. Recovery triggers
one existing refresh path only for a transition affecting this session, not
changes to unrelated entries or a cosmetic hint.

Use two phases on the existing load service, not another coordinator:
`loadContext(sessionId, projectId)` checks connection and fetches catalog session
metadata (existing project-context fallback if needed) and catalog children;
then the cubit resolves the actual plugin and projection and calls
`loadContent(context, interaction, requireCompleteOptions)` only when allowed.
All parameters are required/named. `loadContent` receives a value, never reads
management or needs a previous projection. Existing public load/reload callers
are changed together rather than keeping parallel convenience paths. It can
schedule plugin-backed messages, questions/permissions, queued prompts and
options in parallel after the gate. Reuse the cubit's existing connection/load
fences to apply results against its **current** projection, not the projection
captured before an asynchronous request.

Do not wait indefinitely for a management stream: while unresolved, the cubit
emits the metadata-only state and its snapshot subscription resumes content
loading when evidence arrives. A typed admission refusal during history loading
returns an explicit unavailable load result; the cubit applies generic unavailable
guidance and requests management refresh. It is not an empty history success.

Add foundation `SessionDetailContext` with required session id; nullable project
id, plugin id, title and root status; `SessionArchiveKnowledge` enum (archived,
unarchived, unknown); nullable `List<Session> children` (null = catalog child read
failed, [] = successfully no children); and a `Map<String, SessionStatus>` of
known child statuses. Missing status never means idle. Log a failed child read
and show unavailable child-list guidance while preserving navigation to known
children/links. Catalog children do not require a usable plugin. Only confirmed
unarchived permits mutations; metadata fallback with unknown archive state
remains read-only with metadata-refresh guidance until the catalog resolves it.
Replace the loaded state's `isArchived` storage boolean with archive knowledge
and a derived getter where useful; do not invent false for a failed lookup.

Add `SessionDetailLoadResult.unavailable(context, admissionFailure)` and
`SessionDetailState.unavailable(context, interaction, composerEntry)`, with named
required parameters. The context phase returns its own explicit
context/waiting/failure result. The unavailable state has no messages, options
or pagination fields, but its context retains child browsing and archive facts.
A live block on an already loaded state updates its projection in place:
messages/cursors/children stay untouched, mutations stop, and a failing refresh
never replaces the transcript with the cold shell. Pagination resumes through
its normal error-preserving path when routable; it is unavailable while the
runtime refuses reads. A metadata-only shell must not mark unseen transcript
content as read. Recovery uses the context/content phases to obtain current
history/options and confirmed archive knowledge before activating the composer.

### Repository-owned rejection interpretation (step 3)

`SessionApi` remains transport-only and returns its existing `ApiResponse<T>`;
it neither decides admission semantics nor parses error JSON. Introduce
`repositories/models/session_request_result.dart` with sealed
`SessionRequestResult<T>` variants success(data), admissionRejected(rejection,
cause: ApiError), and failed(cause: ApiError). `SessionRepository` maps results
for `sendMessage` and `getMessages` (including paginated reads), with a required
`expectedPluginId` supplied from resolved context. A repository-private method
parses `NonSuccessCodeError` 503 through the shared Freezed DTO, checks the closed
code and exact expected id, and preserves the original error in either failure
variant. Unknown code/malformed JSON/mismatched id is ordinary failure, not a
lost error or evidence that a send was refused. No service/cubit parses JSON.

The load service consumes these typed history results; the cubit consumes typed
send results. Typed pagination rejection preserves the cursor/messages and
notifies the cubit to refresh management using a typed page-load result instead
of today's null-only failure. Auxiliary questions/permissions/queue reads retain
their existing explicit/logged failure behavior and cannot fabricate send
acceptance; their readiness is governed by the same projection. They need no
new result wrapper merely because they also use the plugin.

Creation is deliberately **not** interpreted as definitely uncreated from this
signal: its multi-step workflow may already have created a session before an
initial prompt is refused. Keep its existing `ApiResponse<Session>`/creation
restoration semantics. Update `NewSessionCubit` only for explicit local composer
handoff acknowledgment, not a new create-session availability or rollback flow.
A generic routing rejection is not proof that all preceding workflow effects
were absent. This boundary avoids broadening an existing-chat fix into creation
transaction redesign.

### Composer storage and handoff details (step 3)

Move only `QueuedSessionSubmission` from its cubit directory to
`foundation/models/composer/queued_session_submission.dart`, updating imports
and exports. It is an immutable value, not queue orchestration. This narrow
causal move allows storage models to refer to it without depending on a cubit.
Keep `PromptSendQueue` and its existing send owner where they are.

New foundation `SessionComposerEntry` (in `session_composer_entry.dart`) contains
required `draft: ComposerDraft`, `attachments: List<ComposerAttachment>`,
`stagedCommand: CommandInfo?`, and `recoveryItems: List<UnsentSessionSubmission>`.
Collections are immutable. `UnsentSessionSubmission` contains the original
`QueuedSessionSubmission` and a closed reason: `harnessUnavailable`; it carries
no mutable retry flag. Add a small `ComposerSubmissionHandoff` enum with
`retainedByComposer` and `takenBySession` in the same foundation area.

Extend the existing `ComposerDraftStorage` map's value to the entry, not a second
map. Existing new-session draft APIs use the same entry shape without inventing
session submissions. `ComposerDraftRepository` owns synchronous named-parameter
read/modify/write operations: `readSessionEntry`, `saveSessionComposer` (update
only draft/attachments/command), `retainUnsentSubmissions` (append named prompt
ids idempotently without modifying the composer), `removeUnsentSubmission`, and
`clearSessionComposer` (clear only editable content, retain recovery items).
Delete an entry only when text, attachments, command and recovery list are all
empty. Attachment-only and command-only content is not an empty draft. Remove
the cubit's redundant `_composerDraft` mirror where repository reads suffice;
retain its public draft getter for view restoration, not as another owner.

`PromptSubmitCallback` becomes `FutureOr<ComposerSubmissionHandoff> Function`
with its existing named payload parameters. `PromptInput` awaits that local
handoff, rechecks mounted/interaction state after existing voice awaits, and
clears only on takenBySession. Session submission returns immediately after
local queue ownership is established, draining unawaited as today’s UI expects;
it does not wait for backend acceptance. The new-session callback returns taken
only when its existing submission owner accepted the input, otherwise retained.
Update the two production shared consumers and their shell/widget test callbacks
in step 3; never add optional compatibility callbacks for these internal APIs.

Use a full-payload composer-change callback rather than a text-only restoration
write: persist on text, command and attachment changes, and after accepted local
handoff clearing. Do not depend on widget `dispose` to recover the final payload.
A live block disables input, cancels/discards active capture using existing voice
ownership, and preserves already-authored text/images/command. A late paste or
transcription result cannot mutate a blocked or replaced composer. Resuming
restores the saved payload; starting recording again requires explicit intent.

Loaded and metadata-only state expose the immutable stored composer entry for
recovery rendering. Cubit methods `resendUnsentSubmission` and
`removeUnsentSubmission` name a prompt id. Copy is presentation-only. Resend is
allowed only with current availability, archive and attachment/command/selection
checks satisfied, then transfers the existing id/payload into the existing local
queue and removes its recovery entry. Invalid selection stays unsent for explicit
correction rather than silently dropping content. These synchronous operations
need no lock: store before removing from the local pending list, and enqueue
before removing a recovery item. Do not clear a newer composer draft on either.

When blocking, move only sendable pending text/command items to recovery storage.
An existing `UnavailableQueuedCommandSubmission` is already terminal for a
separate catalog reason: retain it in the original visible/local-removable queue
slot, do not wrap it as harness recovery or re-enqueue it on resend. A harness
recovery command is revalidated against the current catalog on explicit resend;
if it is no longer offered, keep its original unsent item with command-unavailable
guidance until removal/correction, never convert it into a permanently rejected
variant and enqueue that. Leave active/awaiting-bridge slots alone. Add a narrow queue operation to
settle a definitely rejected active item without `failSend()` requeueing it;
honor existing `_settledElsewhere` evidence first. Only that typed result may
move the active submission to recovery. Accepted/uncertain work still follows
the existing event/snapshot/transport flow. No lifecycle hook moves every active
queue into global storage on disposal. This explicitly does not solve uncertain
sends lost on app exit or backend queue loss after acceptance.

## Architecture and implementation series

Use slug `harness-unavailable-chats` in all six exact PR titles. Execute in order;
each implementation PR must be independently passing. Estimate additions plus
deletions, including generated output/tests, below the 1,500-line soft cap. If a
slice cannot fit, revise this plan and its fixed total before opening that PR.

### 1. 🌱 [harness-unavailable-chats] Plan unavailable chat recovery [step 1/6]

- **What/why:** this plan and tracker; establish behavior and proof boundaries
  before changing submission ownership.
- **Risk/test focus:** low; path/link and plan-consistency validation only.
- **Expected result:** reviewable plan; no user-visible or database change.
- **Size:** approximately 600–750 documentation lines.

### 2. ⚙️ [harness-unavailable-chats] Identify pre-dispatch harness refusals [step 2/6]

- **What:** add a bridge-app-owned typed admission exception at the existing
  runtime acquisition refusal branches, before the plugin operation is invoked.
  Preserve useful diagnostic context/cause on wrapping. Map it at the existing
  request-handler exception boundary to a small Freezed JSON rejection with a
  closed reason code and owning plugin id. Preserve HTTP 503; do not change
  success bodies or make post-dispatch/generation failures claim non-acceptance.
  Map in both applicable handler/router exception paths, without duplicating
  admission policy. No plugin-interface or descriptor edits are expected.
- **Why:** reject stale-client sends honestly without parsing prose or adding a
  second preflight/lock beside `PluginRuntime`.
- **Risk/test focus:** medium; before-call refusal versus possibly-dispatched
  failures, dormant start, other session operations, unchanged older-client
  non-success behavior, unknown enum decoding. Test runtime and actual route.
- **Expected result:** new clients can prove non-acceptance; older clients still
  get non-success. No database or successful-turn behavior change. Existing
  clients do not gain the new UI yet.
- **Size:** 400–800 lines including shared codegen/tests.

### 3. ⚙️ [harness-unavailable-chats] Gate chat actions and retain unsent input [step 3/6]

- **What:** add the pure availability calculator and sealed result; consume
  `PluginManagementService` in `SessionDetailCubit` using its existing identity
  fencing. Project availability independently of history load success, including
  an explicit metadata-only blocked-detail state rather than nullable loaded
  fields or empty transcript sentinels. Update `SessionDetailLoadService` to
  preserve readable content and avoid requiring interactive options for a
  known-blocked view. Keep admission parsing in `SessionRepository` with the
  typed send/history/page outcomes above; preserve ordinary errors and causes.
- Add submission/drain/mutation guards, local-handoff acknowledgment and the
  narrow composer-storage recovery payload described above. Update exhaustive
  state consumers and their tests in this step so it compiles independently;
  step 4 supplies the complete reason-specific presentation and navigation. Update all shared
  composer callback consumers in lockstep. Disable late voice/paste completion
  from causing a send after the block. Recovery never automatically resends a
  definitely unsubmitted/refused item.
- **Why:** one surface-neutral behavioral seam must protect both UI shells,
  preserve authorship and avoid false queued states.
- **Risk/test focus:** medium/high; cubit/load tests with fake management
  streams; FIFO and stable-id semantics; pending versus in-flight versus
  accepted ownership; retained newer drafts and attachments; route disposal;
  cold blocked open; reconnect/bridge switch; unsupported old bridge. Analyze
  `module_core` and affected shared consumer modules.
- **Expected result:** shared actions refuse known unusable harnesses without
  losing local input. No database/schema change; retention remains in memory.
- **Size:** 1,000–1,450 lines including codegen/tests. Do not relocate the entire
  send queue into a singleton or refactor the session cubit as part of this step.

### 4. ⚙️ [harness-unavailable-chats] Explain unavailable chats on both surfaces [step 4/6]

- **What:** compose the shared read-only notice/recovery items in
  `SessionDetailBody`, `SessionDetailLoadedView` and composer controls, including
  cold blocked-detail presentation. Gate pending banners and modal liveness,
  and preserve read-only navigation/background-task browsing. Wire settings
  navigation through `SessionDetailPresentationScope` callbacks supplied by
  mobile and desktop, using path/query params if harness focus is added.
- **Why:** make the cause and next action visible at the place users tried to
  interact, not only in settings. Render “not sent,” “sending,” and accepted
  queued work distinctly; local remove/copy stays usable.
- **Risk/test focus:** medium; shared widget tests for all reasons, read-only
  accessibility/keyboard behavior, live disable with input/dialogs open, draft
  restoration, both shell navigation hooks, recovery with archive/child route
  restrictions still applied. Run directly affected UI/shell tests/analyzers.
- **Expected result:** consistent mobile/desktop read-only UX with actionable
  recovery and no silent resend. No database changes.
- **Size:** 800–1,300 lines including localization/generated code and tests.

### 5. 🌿 [harness-unavailable-chats] Document unavailable chat guarantees [step 5/6]

- **What/why:** reconcile `docs/regression/session-turns.md`,
  `plugin-setup-and-lifecycle.md`, `session-history-and-recovery.md`,
  `questions-and-permissions.md`, `attachments-and-images.md`, and
  `voice-input.md` with delivered behavior. Update verified capability gaps in
  `docs/HARNESS_CAPABILITIES.md`; do not describe planned detection as shipped.
- **Risk/test focus:** low; documentation accuracy, sources and matrix validation.
- **Expected result:** executable feature contracts and honest limits; no new
  user-visible or database change beyond prior steps.
- **Size:** 150–350 documentation lines.

### 6. 🌿 [harness-unavailable-chats] Verify recovery and retire plan [step 6/6]

- **What/why:** run the recorded matrix below, record privacy-safe evidence and
  cleanup in `EVIDENCE.md`, then move this directory to `.plan/completed/` only
  when all required coverage passes.
- **Risk/test focus:** low implementation complexity; real setup/auth mutation
  requires isolated test profiles and restoring settings/runtime configuration.
- **Expected result:** proven recovery behavior; no additional product/database
  change. Partial/Blocked/Fail keeps the plan active.
- **Size:** 150–300 evidence/tracker lines, plus directory move.

## Complexity budget, safeguards and cleanup

- **Persistent mutable state:** zero new database columns, files or migrations.
- **In-memory additions:** one immutable availability projection carried in
  existing cubit state, one owned management stream subscription in its existing
  subscription collection, and richer immutable entries in the existing
  process-local composer-storage map (composer payload + unsent recovery items).
  Any retained known-block reason across disconnect is part of that availability
  value and must be scoped to the existing bridge/connection identity, not a
  second freshness cache. Existing queue counters/ownership remain unchanged.
- The calculator, rejection DTO and local handoff result have no mutable state.
  A settings navigation callback is presentation wiring, not a lifecycle owner.
- **Observed safeguards:** known setup blocks stop enqueue/drain; non-accepted
  submissions are preserved through settings navigation; visible explanations.
- **Ordinary reachable flows:** another client disables/restarts while input or
  a modal is open; runtime removed then refreshed; stale UI sends before a
  management update; cold blocked history load; draft plus pending attachment;
  recovery while another harness remains usable. Existing runtime admission and
  composer handoff checks address these without new locks or timers.
- **Accepted risks:** a short management-update delay, last-known readiness after
  refresh failure, backend auth expiry not detected by inspection, process-local
  retention lost on application exit, existing uncertainty/restart queue limits.
  Do not add watchdogs, polling, credential watchers, durable outboxes, global
  session registries or cross-family locking to close theoretical interleavings.
- **Direct cleanup:** remove unconditional composer clearing after a refused
  local handoff; replace generic retry treatment only for definite harness
  admission refusal; replace duplicated archive-only modal/action predicates
  with composed interaction policy. Do not remove archive/read-only route
  semantics, accepted-prompt parking, busy queues or stale-option recovery.
  No obsolete persisted or wire fields were found. No broad refactor approved.
- **Analytics:** this is correctness/recovery UX, not a new adoption funnel.
  Add no tap/status analytics; retain existing accepted-submission analytics,
  ensuring a refused handoff never counts as an accepted submission.

## Compatibility

Reuse existing management wire fields/events. The sole proposed wire addition
is a structured non-success admission body with a closed discriminator and
unknown-enum handling. New client + old bridge still gates from management when
available; an unstructured error is not proof of non-acceptance. Old client +
new bridge keeps its HTTP failure behavior and is not promised the fixed UX.
Verify public production baselines before implementing compatibility tests;
internal builds create no compatibility obligation. Internal Dart APIs change
in lockstep without shims. No crypto, credential handling or database migration.

## Verification and retirement matrix

Highest required level: **targeted L4 Extended**, cumulative applicable L1–L4
entries for the six affected feature documents, under their authoritative proof
boundaries. This is not a repository-wide L4 campaign. Record concrete builds,
registered harness set, platform targets and executed feature entries before
running; do not silently omit a required plugin/platform or lower the level.

- **Automated:** exhaustive existing setup/runtime states, unknown enums, load
  states and precedence using neutral fixtures; every registered harness remains
  listed. Runtime admission + serialized route tests prove zero plugin calls
  on refusal and no false definite rejection after dispatch. Cubit/composer
  tests prove no enqueue/send/reply/voice bypass, no automatic resend of refused
  work, preserved drafts/attachments across route disposal, existing uncertainty
  reconciliation, and archive restrictions after recovery.
- **Client E2E:** macOS desktop plus iOS and Android clients against a macOS
  bridge; one backend-neutral unavailable-state scenario on the alternate mobile
  platform satisfies its variation, not a full per-harness cross-product.
  Render every reason with controlled fixtures, then traverse a real
  client → relay → bridge → live harness journey for Claude authentication
  failure → restart → blocked chat → settings login/refresh → explicit resend
  and reply. Use an isolated authorized test profile, never revoke the user's
  normal credentials. Include settings round-trip and cold-open blocked history.
- **Harness matrix:** every current registered production harness through its
  applicable existing management controls on one client surface, including
  disabled/restore and relevant setup metadata. Exercise runtime-missing/restore
  on one representative managed harness and one local-only harness. Claude is
  mandatory for the observed auth case; one supporting ACP harness supplies a
  second implementation family. Do not demand live auth expiry from a harness
  whose inspection cannot expose it: verify the limitation and neutral fallback.
- **Recovery/multi-client:** on desktop and primary mobile, block from the other
  surface while text/attachments or a question/permission dialog is open; ensure
  no mutation and no automatic grant/send. Keep a second harness operational.
  Exercise dormant/starting/degraded success, busy queue behavior, reconnect,
  management-refresh failure and same plugin id on a different bridge.
- **Compatibility:** automated old/missing-management endpoint and unknown
  metadata/rejection fixtures, plus one public old-bridge/new-client and
  new-bridge/old-client smoke if such supported public baselines exist. Record
  the release evidence if a pair is genuinely inapplicable.
- **Not required:** packaged installers, stores, production analytics, alternate
  bridge OS matrix, deliberate app-kill persistence or new credential detection.
  No delivered behavior claims those boundaries.

Run directly relevant suites/analyzers for each implementation step; CI owns the
full matrix. Architecture-bearing implementation steps receive scoped reviews
under the repository rules. Planning/docs-only PRs do not run Dart/Flutter tests.
Missing auth accounts or devices makes the relevant matrix Blocked/Partial,
never passed. Matrix reduction requires explicit user acceptance recorded here.

## Architecture review

- First review: rejected at the pre-review gate for insufficiently specific
  ownership/contracts. Added exact files, models, wire schema and handoff APIs.
- Clarification review: pre-review gate passed; architecture verdict rejected
  with concrete ownership/data-flow findings. Applied the valid findings
  directly, without a third review: a sole cubit projection owner with explicit
  context/content phases; refresh-error presentation; child/archive metadata;
  routing response **builder**; repository-owned send/history/page mapping;
  shared `di/cubit_composition.dart` wiring; and exclusion of already-unavailable
  commands from automatic recovery transfer.
- Kept correction scope bounded: did not adopt generic create-session admission
  interpretation or new wrappers for every auxiliary read. Creation can have
  earlier side effects and is outside this existing-chat fix; its local composer
  handoff still updates in lockstep. Existing auxiliary failure behavior remains.
- The revised plan has not received an approved review verdict. Findings were
  addressed under the repository's apply-valid-findings-without-re-review rule.
  No implementation or live reproduction has run.
