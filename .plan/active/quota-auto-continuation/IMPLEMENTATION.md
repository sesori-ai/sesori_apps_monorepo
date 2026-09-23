# Implementation contract

Concrete ownership supplement to [PLAN.md](PLAN.md). New names below are
proposed; existing files retain their current responsibilities.

## Workspace map

| Workspace | Planned change |
|---|---|
| `shared/sesori_shared` | Freezed continuation view/request, additive `Session.autoContinuation`, barrel and generated serializers. |
| `bridge/sesori_plugin_interface` | Typed quota interruption/reset/capability and named-session readiness contracts. |
| Supporting `bridge/sesori_plugin_*` | Plugin-owned parsers, terminal reporting and readiness checks; all descriptors/APIs implement the new internal contracts. |
| `bridge/app` | Storage, neutral projection, policy, triggers, route, prompt dispatch and cancellation. |
| `client/module_core` | Session API/repository method, continuation service, session-detail cubit action/state and DI. Pure Dart. |
| `client/module_app_ui` | Shared chat notice, indicator, overflow entry, localization sources and generated localization output. |
| `client/app`, `client/desktop` | DI/constructor and menu composition wiring only where required by shared chat entry points. No scheduler or stored preference in shells. |
| `docs` | Harness matrix and regression documents named in PLAN.md. |

## Files, classes and dependencies

Paths are relative to each named workspace's `lib/src/`, except shell wiring.

| Owner / layer | Proposed file/class | Constructor dependencies and responsibility |
|---|---|---|
| Plugin interface / Foundation | `models/plugin_quota_interruption.dart`: `PluginQuotaInterruption`, sealed `PluginQuotaReset`, enum `PluginQuotaReportingSupport` | Immutable error-message ID, observed-at UTC, known reset-at UTC or unknown. Capability: conditional/unavailable. |
| Plugin interface / existing API | `bridge_sse_event.dart`: `BridgeSseSessionQuotaBlocked`; `BridgePluginDescriptor.quotaReportingSupport`; `BridgePluginApi.getQuotaContinuationReadiness` | Event carries backend session ID/interruption. Descriptor declares conditional reporting without starting a runtime. Required named-session readiness returns `PluginQuotaContinuationReadiness` enum: idle, busy, retrying, queued, awaitingInput, unavailable, unknown. Update all implementors together. |
| Shared / Foundation | `models/sesori/session_auto_continuation.dart`: `SessionAutoContinuationView`, `AutoContinuationAvailability`, sealed `SessionAutoContinuationStatus`, enum `AutoContinuationPauseReason` | Independent enabled preference, reporting availability, and status: idle, resetKnown(resetAt, continueAt), resetUnknown, attempted, submissionFailed(reason), paused(resetAt, continueAt, reason). Reasons are bounded enums. Known-reset evidence can exist while off; UI claims scheduled only when on and not paused. |
| Shared / Foundation | `models/sesori/set_session_auto_continuation_request.dart`: `SetSessionAutoContinuationRequest` | Required named sessionId/enabled. Response reuses Session; no duplicate response envelope. |
| Bridge API | `api/database/tables/session_continuation_table.dart`: `SessionContinuationTable`, `SessionContinuationDto`; `api/database/daos/session_continuation_dao.dart`: `SessionContinuationDao` | DAO takes AppDatabase. DTO holds session ID, enabled and outcome JSON. No business policy in SQL. |
| Bridge Repository model | `repositories/models/session_continuation_record.dart`: `SessionContinuationRecord`, sealed `SessionContinuationOutcome` | Durable variants: none; resetKnown(errorMessageId, observedAt, resetAt); resetUnknown(errorMessageId, observedAt); consumed(errorMessageId, promptId, attemptedAt); submissionFailed(errorMessageId, reason); paused(errorMessageId, observedAt, resetAt, reason). Paused retains the observation for a later due check. |
| Bridge Repository | `repositories/session_continuation_repository.dart`: `SessionContinuationRepository` | Takes SessionContinuationDao and PluginRuntime. Sole storage write/encoding API: read/readMany, readEnabledObservedBefore(cutoff), setEnabledAlreadyReserved, recordObservationForCurrentGenerationAlreadyReserved, consumeAlreadyReserved, pauseAlreadyReserved, recordFailureAlreadyReserved, cancelCurrentObservationAlreadyReserved. Source-driven writes use the existing generation fence. No timer, scheduling arithmetic, stream, peer-repository dependency or cache. |
| Bridge Repository mapper | `repositories/mappers/session_continuation_mapper.dart`: `SessionContinuationMapper` | Stateless API DTO/domain conversion only; no scheduling policy. |
| Bridge existing Repository | `SessionRepository` | Adds data-only wrappers for declared reporting and named-session readiness through its plugin/runtime seam. Does not depend on continuation repository/service. Base catalog projection remains unchanged. |
| Bridge Service | `services/session_view_service.dart`: `SessionViewService` | Takes SessionRepository, SessionContinuationRepository and fixed buffer. Enriches base Sessions, batches record reads for lists and calculates continueAt. Existing get/list/child handlers, mutation responses and SessionEventService created/updated projection call this Layer 3 owner. No existing data ownership moves. |
| Bridge Service | `services/session_continuation_service.dart`: `SessionContinuationService` | Takes continuation repository, SessionRepository, SessionViewService, SessionOperationDispatcher, SessionPromptService, SessionMutationDispatcher, fixed buffer and clock. Owns setEnabled, observeQuota, observeSupersedingActivity, runDue. Computes cutoff = now - buffer; no direct PluginRuntime dependency or mutable job list. |
| Bridge event trigger | `listeners/session_quota_event_listener.dart`: `SessionQuotaEventListener` | Takes typed post-normalization event source and continuation service. Owns start/subscription/dispose; sequentially delegates quota/new-user/selection signals, with source-generation fencing again at repository commit. Uses existing event producer, no new controller/map. |
| Bridge time trigger | `listeners/session_continuation_timer_listener.dart`: `SessionContinuationTimerListener` | Takes continuation service and timer factory. Owns start/tick/dispose and one self-rescheduling timer; awaits runDue before rearming. |
| Bridge routing / Consumer | `routing/set_session_auto_continuation_handler.dart`: `SetSessionAutoContinuationHandler` | Takes continuation service. BodyRequestHandler with shared request and Session response; no storage/policy in handler. |
| Client existing API/Repository | `SessionApi.setAutoContinuation`, `SessionRepository.setAutoContinuation` | Existing RelayHttpApiClient; preserve typed API success/failure. |
| Client Service | `services/session_auto_continuation_service.dart`: `SessionAutoContinuationService` | Takes client SessionRepository. Executes acknowledged mutation and translates unavailable/failure outcomes; no local preference/timer. |
| Client Consumer | `cubits/session_detail/session_detail_cubit.dart` and state | Inject continuation service; returned Session and normal SSE update the same state. Mutation progress/failure cannot imply optimistic scheduling. |
| Shared UI Consumer | `features/session_detail/widgets/session_auto_continuation_notice.dart`: `SessionAutoContinuationNotice`; existing `session_detail_body.dart` | Typed view and callbacks; both controls call the same cubit action. Durable paused status and existing plugin/connection state expose scheduling limits. |

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

DAO methods are read, readMany, readEnabledObservedBefore and transactional upsert. Repository
methods own transitions and ignore duplicate observations/consumption of the
same ID. Read enabled known-reset/paused records against the cutoff provided by
the service; repository/DAO never calculate a buffer or read the clock. Add no
independent due timestamp. Register table/DAO in
api/database/database.dart and create the new table in the next schema step
(current checkout 16 -> 17; use the next actual version after rebasing). Export
schema and regenerate Drift/database.steps.dart; no transcript backfill.

One repository/DAO pair owns writes. Transition authority is explicit:
continuation service writes enabled/observed state; prompt service alone consumes
a due attempt and records its submission failure; existing mutation services
cancel at their reserved seams. Every writer calls the same repository, never
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
   SessionQuotaEventListener subscribes to this typed post-validation source,
   preserving order. It adds no event producer and does not intercept raw frames.
3. Both peer listeners call SessionContinuationService. observeQuota enters
   SessionOperationDispatcher, then calls the repository's generation-fenced
   already-reserved write. The repository uses PluginRuntime.commitCurrentGeneration
   for the supplied source generation; policy never calls runtime directly.
   Source-driven cancellation uses the same fence. Terminal handoff never arms
   a wait. runDue calculates a cutoff, reads eligible records and calls
   SessionPromptService.sendScheduledContinuation sequentially; that method
   owns its one dispatcher entry and normal prompt acceptance.
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

Construct repositories before services and listeners after services in
orchestrator.dart. Both listeners expose start/dispose and own one trigger:
normalized event subscription versus self-rescheduling timer. Start after
routing/event normalization is ready; restart recreates them and runs an
immediate due tick. No separate availability subscription: paused due records
are checked next tick. Dispose both listeners before draining the existing
operation dispatcher. Total new runtime resources: one subscription and one
timer, their lifecycle flags, and no controller/map/job registry.

## Dispatch preflight and cancellation

SessionPromptService gains continuation-repository, SessionViewService and
mutation-dispatcher dependencies. Its scheduled method reserves the existing
lane, reloads enabled/current outcome, and validates the service-supplied due
cutoff. It reads getSessionMessages for that named session through the existing
SessionRepository, plus new getQuotaContinuationReadiness through that same
repository/plugin boundary. Do not interpret generic getSessionStatus null as
idle. The plugin readiness operation uses its own native session owner, can
recognize a persisted non-resident idle session, and explicitly distinguishes
busy/retrying/queued/awaiting-input/unavailable/unknown. Only idle can pass.
This operation uses normal eligible runtime acquisition; it cannot enable a
disabled harness. The supported-plugin tests must prove restart/non-resident
readiness, not merely resident-map lookup.

The last message must still be the stored terminal PluginMessageError.id as
projected to MessageError.id. Existing snapshots return the whole named session;
inspect its tail without new pagination, recursive reads or cross-session
scans. A newer message consumes the obsolete wait. Unreadable snapshot or
non-idle readiness persists paused with the original observation/reset and a
bounded reason. Publish that state; paused remains eligible for later due
checks. Do not persist/broadcast an unchanged paused state on every tick.

Use SessionMessagesSnapshot.promptDefaults from that read as the authoritative
selection. Map agent directly; map its AgentModel providerID/modelID to
PromptModel(providerID: ..., modelID: ...), and a present model.variant to
SessionVariant(id: ...). Preserve meaningful nulls when the harness has no
explicit selection. Parts are `[PromptPart.text(text: "Continue.")]`; command
and normalizedCommand are null. Do not reconstruct or repeat the failed prompt.

Persist consumed with generated promptId/attemptedAt, then invoke existing
_sendPrompt with those typed values. Do not call public sendPrompt
inside a reserved lane. Publish the updated view. Preserve original submission
error/stack in logs, record bounded failure, and do not retry the consumed
observation. AcceptedPromptsRepository remains the deduplication owner; this
does not close the documented crash window. Cancellation from any already
reserved service body calls cancelCurrentObservationAlreadyReserved directly
on the repository and publishes after success; it never calls a dispatcher-
entering continuation method. External toggles/observations enter the lane via
continuation service, and timer sends enter via prompt service exactly once.

| Change | Existing authoritative seam |
|---|---|
| Toggle | SessionContinuationService.setEnabled under SessionOperationDispatcher; false prevents due selection after commit. |
| Accepted manual prompt/command | SessionPromptService._sendPrompt after backend acceptance inside its reserved lane; cancel current wait, keep enabled. Scheduled send has already consumed it, so cancellation there is a no-op. |
| Accepted Stop | SessionAbortService.abortSession inside its dispatched body; cancel pending wait. A refused stop retains current refusal semantics. |
| Archive | SessionLifecycleService._doArchive after successful archive in its reserved path; cancel wait. |
| Delete | SessionDeletionService / SessionMutationDispatcher.deleteSession / FK removal. |
| Native new user message/effective selection | Normalized adapter -> observeSupersedingActivity -> existing operation dispatcher -> cancel old observation. A client draft picker change is not authoritative. |
| Native busy/retry/queued work | Existing status/queue blocks dispatch; accepted/native activity invalidates old observation. Due-session snapshot catches work performed while bridge was offline. |

Fresh resetAt must be strictly after observedAt; relative duration must be
positive and finite. Invalid fresh values become resetUnknown. Persisted valid
waits remain eligible when resetAt becomes earlier than now during sleep.
Consumed observation IDs never rearm. No new dedupe set, restart cache or
account polling is needed.
