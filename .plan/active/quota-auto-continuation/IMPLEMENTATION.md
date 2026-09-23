# Implementation contract

Concrete ownership supplement to [PLAN.md](PLAN.md). New names below are
proposed; existing files retain their current responsibilities.
[PLUGINS.md](PLUGINS.md) specifies the plugin file, class, layer and dependency
map, including the disposition of unverified harnesses.

## Workspace map

- **`shared/sesori_shared`:** Freezed continuation view/request, additive `Session.autoContinuation`, barrel
  and generated serializers.

- **`bridge/sesori_plugin_interface`:** Typed quota interruption/reset/capability and named-session
  readiness contracts.

- **Supporting `bridge/sesori_plugin_*`:** Plugin-owned parsers, terminal reporting and readiness checks;
  all descriptors/APIs implement the new internal contracts.

- **`bridge/app`:** Storage, neutral projection, policy, triggers, route, prompt dispatch and cancellation.

- **`client/module_core`:** Session API/repository method, continuation service, session-detail cubit
  action/state and DI. Pure Dart.

- **`client/module_app_ui`:** Shared chat notice, indicator, overflow entry, localization sources and
  generated localization output.

- **`client/app`, `client/desktop`:** DI/constructor and menu composition wiring only where required by
  shared chat entry points. No scheduler or stored preference in shells.

- **`docs`:** Harness matrix and regression documents named in PLAN.md.

## Files, classes and dependencies

Paths are relative to each named workspace's `lib/src/`, except shell wiring.

### Owner / layer: Plugin interface / Foundation

**Proposed file/class:** `models/plugin_quota_interruption.dart`: `PluginQuotaInterruption`, sealed
`PluginQuotaReset`, enum `PluginQuotaReportingSupport`

**Constructor dependencies and responsibility:** Immutable error-message ID, observed-at UTC, known reset-at
UTC or unknown. Capability: conditional/unavailable.

### Owner / layer: Plugin interface / existing API

**Proposed file/class:** `bridge_sse_event.dart`: `BridgeSseSessionQuotaBlocked`;
`BridgePluginDescriptor.quotaReportingSupport`; `BridgePluginApi.getQuotaContinuationReadiness`

**Constructor dependencies and responsibility:** Event carries backend session ID/interruption. Descriptor
declares conditional reporting without starting a runtime. Required named-session readiness returns
`PluginQuotaContinuationReadiness` enum: idle, busy, retrying, queued, awaitingInput, unavailable, unknown.
Update all implementors together.

### Owner / layer: Shared / Foundation

**Proposed file/class:** `models/sesori/session_auto_continuation.dart`: `SessionAutoContinuationView`,
`AutoContinuationAvailability`, sealed `SessionAutoContinuationStatus`, enum `AutoContinuationPauseReason`

**Constructor dependencies and responsibility:** Independent enabled preference, reporting availability, and
status: idle, resetKnown(resetAt, continueAt), resetUnknown, attempted, submissionFailed(reason),
paused(resetAt, continueAt, reason). Reasons are bounded enums. Known-reset evidence can exist while off; UI
claims scheduled only when on and not paused.

### Owner / layer: Shared / Foundation

**Proposed file/class:** `models/sesori/set_session_auto_continuation_request.dart`:
`SetSessionAutoContinuationRequest`

**Constructor dependencies and responsibility:** Required named sessionId/enabled. Response reuses Session;
no duplicate response envelope.

### Owner / layer: Bridge API

**Proposed file/class:** `api/database/tables/session_continuation_table.dart`: `SessionContinuationTable`,
`SessionContinuationDto`; `api/database/daos/session_continuation_dao.dart`: `SessionContinuationDao`

**Constructor dependencies and responsibility:** DAO takes AppDatabase. DTO holds session ID, enabled and
outcome JSON. No business policy in SQL.

### Owner / layer: Bridge Repository model

**Proposed file/class:** `repositories/models/session_continuation_record.dart`:
`SessionContinuationRecord`, sealed `SessionContinuationOutcome`

**Constructor dependencies and responsibility:** Durable variants: none; resetKnown(errorMessageId,
observedAt, resetAt); resetUnknown(errorMessageId, observedAt); consumed(errorMessageId, promptId,
attemptedAt); cancelled(errorMessageId); submissionFailed(errorMessageId, reason);
paused(errorMessageId, observedAt, resetAt, reason,
recheckAt). Paused retains the observation and a persisted recheck deadline.

### Owner / layer: Bridge Repository

**Proposed file/class:** `repositories/session_continuation_repository.dart`:
`SessionContinuationRepository`

**Constructor dependencies and responsibility:** Takes SessionContinuationDao and PluginRuntime. Sole
storage write/encoding API: read/readMany, readEnabledReadyToCheck(resetCutoff, pausedRecheckCutoff), readReadyToCheck,
setEnabledAlreadyReserved, recordObservationForCurrentGenerationAlreadyReserved, consumeAlreadyReserved,
pauseAlreadyReserved, recordFailureAlreadyReserved, cancelCurrentObservationAlreadyReserved. Source-driven
writes use the existing generation fence. No timer, scheduling arithmetic, stream, peer-repository
dependency or cache.

### Owner / layer: Bridge Repository mapper

**Proposed file/class:** `repositories/mappers/session_continuation_mapper.dart`:
`SessionContinuationMapper`

**Constructor dependencies and responsibility:** Stateless API DTO/domain conversion only; no scheduling
policy.

### Owner / layer: Bridge existing Repository

**Proposed file/class:** `SessionRepository`

**Constructor dependencies and responsibility:** Adds data-only wrappers for declared reporting and
named-session readiness through its plugin/runtime seam. Does not depend on continuation repository/service.
Base catalog projection remains unchanged.

### Owner / layer: Bridge Service

**Proposed file/class:** `services/session_view_service.dart`: `SessionViewService`

**Constructor dependencies and responsibility:** Takes SessionRepository, SessionContinuationRepository and
fixed buffer. Enriches base Sessions, batches record reads for lists and calculates continueAt. Existing
get/list/child handlers, mutation responses and SessionEventService created/updated projection call this
Layer 3 owner. No existing data ownership moves.

### Owner / layer: Bridge Service

**Proposed file/class:** `services/session_continuation_service.dart`: `SessionContinuationService`

**Constructor dependencies and responsibility:** Takes continuation repository, SessionRepository,
SessionViewService, SessionOperationDispatcher, SessionPromptService, SessionMutationDispatcher,
fixed reset buffer, fixed five-minute pause recheck delay and clock. Owns setEnabled, observeQuota,
observeSupersedingActivity, runDue and all scheduled-attempt transitions. Computes resetCutoff = now - buffer
and pausedRecheckCutoff = now; no direct PluginRuntime dependency or mutable job list.

### Owner / layer: Existing bridge event trigger

**Existing file/class:** `orchestrator.dart` / `OrchestratorSession` ordered normalized-event path.

**Dependency and responsibility:** Inject continuation service. The existing
_processPluginEventInOrder chain awaits quota/supersession handling through
_processPluginEvent before releasing that source and acknowledging a later
terminal handoff. This is trigger delegation only; policy remains in the service.
Reuse the existing subscription and per-plugin processing tail; no additional
listener, subscription, controller or completion map is needed.

### Owner / layer: Bridge time trigger

**Proposed file/class:** `listeners/session_continuation_timer_listener.dart`:
`SessionContinuationTimerListener`

**Constructor dependencies and responsibility:** Takes continuation service and timer factory. Owns
start/tick/dispose and one self-rescheduling timer; awaits runDue before rearming.

### Owner / layer: Bridge routing / Consumer

**Proposed file/class:** `routing/set_session_auto_continuation_handler.dart`:
`SetSessionAutoContinuationHandler`

**Constructor dependencies and responsibility:** Takes continuation service. BodyRequestHandler with shared
request and Session response; no storage/policy in handler.

### Owner / layer: Client existing API/Repository

**Proposed file/class:** `SessionApi.setAutoContinuation`, `SessionRepository.setAutoContinuation`

**Constructor dependencies and responsibility:** Existing RelayHttpApiClient; preserve typed API
success/failure.

### Owner / layer: Client Service

**Proposed file/class:** `services/session_auto_continuation_service.dart`: `SessionAutoContinuationService`

**Constructor dependencies and responsibility:** Takes client SessionRepository. Executes acknowledged
mutation and translates unavailable/failure outcomes; no local preference/timer.

### Owner / layer: Client Consumer

**Proposed file/class:** `cubits/session_detail/session_detail_cubit.dart` and state

**Constructor dependencies and responsibility:** Inject continuation service; returned Session and normal
SSE update the same state. Mutation progress/failure cannot imply optimistic scheduling.

### Owner / layer: Shared UI Consumer

**Proposed file/class:** `features/session_detail/widgets/session_auto_continuation_notice.dart`:
`SessionAutoContinuationNotice`; existing `session_detail_body.dart`

**Constructor dependencies and responsibility:** Typed view and callbacks; both controls call the same cubit
action. Durable paused status and existing plugin/connection state expose scheduling limits.

Tests and generated files accompany these owners. Add no generic scheduler
framework and do not reorganize existing session classes.

## Wire and storage

Route: **PATCH /session/auto-continuation**, following the existing
PATCH /session/title body-routing convention. Body is `{sessionId, enabled}`;
success returns the authoritative Session. Repeating a value is a no-op success.
Unsupported enabling returns a typed unsupported API outcome; disabling an
existing preference remains possible when reporting is unavailable.

Add `required SessionAutoContinuationView? autoContinuation` to shared Session.
Omitted/null from an older peer means feature unavailable. A new bridge returns
a non-null view, including unavailable reporting capability. Generate shared
Freezed/JSON files and retain `include_if_null: false`. Reuse wire
`session.updated` / `SesoriSseEvent.sessionUpdated`; no new wire SSE discriminator
is needed. New internal quota events are consumed by policy, not serialized to
clients by `sse/bridge_event_mapper.dart`.

Wire resetAt/continueAt timestamps use UTC epoch milliseconds, matching existing
session time conventions. Plugins convert provider seconds, relative durations
and named-zone clock text before reporting an internal UTC instant.

Table `session_continuations`: session_id is primary key/FK to
sessions_table.session_id with ON DELETE CASCADE; enabled is a non-null boolean;
outcome_json is a non-null closed tagged object. The repository serializes its
sealed domain value; the API DTO carries text and never imports higher-layer
domain types. A missing row projects disabled/none.

DAO methods are read, readMany, readEnabled and transactional upsert. They
return raw DTOs; readEnabled filters only the stored boolean. The repository
maps outcome JSON and applies one eligibility predicate to both its batch
readEnabledReadyToCheck and named-session readReadyToCheck. The service supplies
resetCutoff = now - buffer and pausedRecheckCutoff = now. Eligible records are
enabled, have a known reset with resetAt <= resetCutoff, and, if paused, satisfy
recheckAt <= pausedRecheckCutoff. observedAt never determines when a wait is due.
Both reads use that same repository predicate; preflight does not duplicate it.
No SQL branch decodes outcomes or selects scheduling states. Repository/DAO
never calculate delays or read the clock. The reset deadline is not duplicated;
recheckAt is only the next eligibility check after a pause.

Register table/DAO in api/database/database.dart and create the new table in the
next schema step (current checkout 16 -> 17; use the next actual version after
rebasing). Export schema and regenerate Drift/database.steps.dart; no transcript
backfill.

One repository/DAO pair owns writes. Transition authority is explicit:
continuation service owns setting changes, observations, scheduled preflight,
pause/consume/failure transitions and publication. Existing mutation services
only invalidate the current observation at their reserved seams through the
repository's idempotent cancellation primitive; they contain no scheduling
policy. Cancellation stores cancelled(errorMessageId), retaining deduplication
identity without inventing a prompt ID; the shared view projects it as idle. Every writer calls the same
repository, never
the DAO. No two services independently decide to send. Existing session FK
deletion removes the record; this feature adds no cascade algorithm.

## Ordered flow and trigger lifecycle

1. Plugin emits terminal BridgeSseSessionQuotaBlocked. Extend
   repositories/mappers/session_event_mapper.dart to identify/translate its
   backend ID and produce NormalizedQuotaInterruptionEvent in
   repositories/models/normalized_bridge_event.dart, with bridge session ID and
   a backend-neutral repository value.
2. Existing PluginEventListener -> SessionEventDispatcher ->
   SessionEventService.normalize supplies identity and generation validation.
   OrchestratorSession's existing ordered normalized-event owner awaits the continuation
   service for quota/new-user/selection payloads before finishing that event.
   It adds no event producer and does not intercept raw frames.
3. The existing ordered event owner and new timer listener call
   SessionContinuationService. observeQuota enters
   SessionOperationDispatcher, then calls the repository's generation-fenced
   already-reserved write. The repository uses PluginRuntime.commitCurrentGeneration
   for the supplied source generation; policy never calls runtime directly.
   Source-driven cancellation uses the same fence. Terminal handoff never arms
   a wait. runDue calculates both cutoffs, reads eligible records and calls
   its private due-attempt method sequentially. That method enters the existing
   dispatcher once, reloads the eligible record through the repository predicate, performs
   preflight, and owns pause/consume/failure/publication. It delegates only prompt
   submission to SessionPromptService.sendPromptAlreadyReserved.
4. Add SessionContinuationUpdated and a small notification method to existing
   SessionMutationDispatcher. After writing, the caller obtains the updated
   Session through SessionViewService and publishes it without another lane.
   Existing SessionMutationListener -> dispatchLocalEvent / _mapLocalMutation
   -> BridgeSseSessionUpdated -> session.updated delivers the view. Reuse the
   existing mutation stream; no new change controller.
5. Client SessionApi -> SessionRepository -> SessionAutoContinuationService ->
   SessionDetailCubit handles mutations. Returned Session and SSE converge on
   the same state. GetSession/list/reconnect use SessionViewService projection.
   Shared body/menu/notice render it. Clients only format authoritative times.

Construct repositories before services and the timer listener after services
in orchestrator.dart. The timer owns start/tick/dispose; start it after event
normalization/routing is ready and run an immediate due tick on restart.
Quota handling is awaited inside the existing _processPluginEventInOrder tail,
so a later terminalHandoffConsumed acknowledgement cannot overtake an admitted
quota write waiting on the session lane. No separate availability subscription:
paused records re-enter the query at recheckAt. Dispose the timer and drain the
existing event owner before draining the session-operation dispatcher. Total
new runtime resources: one timer and its lifecycle flags; no subscription,
controller, completion map or job registry.

Retain the existing generation admission fence: an event whose generation stops
being routable before its durable write is admitted is rejected and never shown
as scheduled. This plan promises restart recovery for persisted observations,
not durable delivery of every emitted/normalized frame. Do not add a stop-time
write permit or broaden runtime eligibility to erase that bounded capture gap.
Test a quota event queued behind a session operation followed by terminal handoff:
its admitted write must settle before handoff acknowledgement. Also test generation
rejection before admission, with no false scheduled view.

## Dispatch preflight and cancellation

SessionContinuationService owns the whole scheduled-attempt workflow. Inside
its one reserved lane, call repository.readReadyToCheck for the named session
with the service-supplied cutoffs; a null result skips the attempt. Then call
getQuotaContinuationReadiness through SessionRepository; only idle proceeds
to getSessionMessages for that named session. Do not interpret generic getSessionStatus null as
idle. The plugin readiness operation uses its own native session owner, can
recognize a persisted non-resident idle session, and explicitly distinguishes
busy/retrying/queued/awaiting-input/unavailable/unknown. Only idle can pass.
This operation uses normal eligible runtime acquisition; it cannot enable a
disabled harness. The supported-plugin tests must prove restart/non-resident
readiness, not merely resident-map lookup.

The last message must still be the stored terminal PluginMessageError.id as
projected to MessageError.id. Existing snapshots return the whole named session;
inspect its tail without new pagination, recursive reads or cross-session
scans. A newer message cancels the obsolete wait. Unreadable snapshot or
non-idle readiness persists paused with the original observation/reset and a
bounded reason, plus recheckAt = clock.now() + five minutes. The same delay
applies to every pause reason; persist it in the existing record so restart
does not immediately recheck a paused session. Each unsuccessful recheck moves
that deadline forward by five minutes. Publish only changes to the visible
paused view, not bookkeeping-only deadline updates. The 30-second timer skips
paused rows until that deadline. Thus a disabled harness or permission prompt
performs no repeated transcript reads, and an unreadable idle session reads at
most once per five minutes. No retry counter or additional event subscription
is needed.

Use SessionMessagesSnapshot.promptDefaults from that read as the authoritative
selection. Map agent directly; map its AgentModel providerID/modelID to
PromptModel(providerID: ..., modelID: ...), and a present model.variant to
SessionVariant(id: ...). Preserve meaningful nulls when the harness has no
explicit selection. Parts are `[PromptPart.text(text: "Continue.")]`; command
and normalizedCommand are null. Do not reconstruct or repeat the failed prompt.

The continuation service persists consumed with generated promptId/attemptedAt,
then calls SessionPromptService.sendPromptAlreadyReserved with those typed
values. That narrow method delegates to existing _sendPrompt without acquiring
a second lane. It owns normal prompt acceptance only: no quota reads, clock,
pause scheduling, consume/failure decisions or continuation-view publication.
The continuation service publishes the outcome. Preserve original submission
error/stack in logs, record bounded failure, and do not retry the consumed
observation. AcceptedPromptsRepository remains the deduplication owner; this
does not close the documented crash window. Cancellation from any already
reserved service body calls cancelCurrentObservationAlreadyReserved directly
on the repository and publishes after success; it never calls a dispatcher-
entering continuation method. External toggles, observations and due attempts
enter the lane through continuation service exactly once. Prompt service has no
dependency on continuation service, avoiding a cycle.

- **Toggle:** SessionContinuationService.setEnabled under SessionOperationDispatcher; false prevents due
  selection after commit.

- **Manual prompt/command:** SessionPromptService._sendPrompt persists cancellation after existing
  archive/accepted-ID checks and before backend submission inside its reserved lane; keep enabled. An
  already-consumed scheduled attempt is unchanged.

- **Stop:** SessionAbortService.abortSession persists cancellation inside its dispatched body before
  invoking backend abort. A refused abort keeps its existing failure result; the wait stays cancelled.

- **Archive:** SessionLifecycleService._doArchive persists cancellation before invoking archive in its
  reserved path. A failed archive leaves the wait cancelled.

- **Delete:** SessionDeletionService / SessionMutationDispatcher.deleteSession / FK removal.

- **Native new user message/effective selection:** Normalized adapter -> observeSupersedingActivity ->
  existing operation dispatcher -> cancel old observation. A client draft picker change is not
  authoritative.

- **Native busy/retry/queued work:** Existing status/queue blocks dispatch; accepted/native activity
  invalidates old observation. Due-session snapshot catches work performed while bridge was offline.

SessionPromptService, SessionAbortService and SessionLifecycleService gain the
continuation repository, SessionViewService and SessionMutationDispatcher only
for cancellation and its view publication. They do not depend on the continuation
service, own its clock, or decide scheduled eligibility. The prompt service's
new already-reserved submission method reuses its existing dependencies/body.

For Stop/archive, cancellation persistence is a prerequisite: if it fails, do
not invoke the primary operation, and return that explicit failure. Once durable,
never restore the wait, even if the primary operation fails. Publish the
cancelled view without allowing a publication failure to change the primary
result; log recovered publication errors with operation/session context and
original error/stack. Reconnect reads recover the durable state. Manual prompt
acceptance uses the same before-submission cancellation ordering inside its
reserved body, so a failed new prompt can cancel the old wait but cannot leave
an automatic duplicate behind. Preference remains enabled in all these cases.
No outbox, retry job, or extra lifecycle state is required.

Required focused coverage includes cancellation-write failure before Stop or
archive (no primary call), publication failure after successful Stop/archive
(primary success preserved, durable cancellation still blocks send), and a
refused primary operation after cancellation (no rearming). Also cover a reset
several days after observedAt:
advancing past observedAt + buffer cannot select it, while resetAt + buffer
can. For paused states, repeated 30-second ticks before recheckAt must cause
no plugin or history calls; at the deadline, non-idle readiness still skips
history. Restart preserves the recheck deadline and visible state.

Fresh resetAt must be strictly after observedAt; relative duration must be
positive and finite. Invalid fresh values become resetUnknown. Persisted valid
waits remain eligible when resetAt becomes earlier than now during sleep.
Consumed and cancelled observation IDs never rearm. No new dedupe set, restart cache or
account polling is needed.
