# Read-only chats for unavailable harnesses

## Goal and user-approved scope

Prevent interaction with an existing chat when its owning harness is known to
be unavailable. Keep the chat readable, clearly explain the blocking state, and
restore interaction when authoritative harness status becomes usable again.
Applies to mobile, desktop, and all registered production harnesses through the
existing backend-neutral management contract.

**The user explicitly selected input gating only**, then clarified:

> I actually don't care about queue recovery. if we correctly stop the user
> from attempting to message an unavailable harness we don't even need recovery.

This replaces the earlier broader proposal. There is **no queue recovery work**:
no outbox, rejected-submission retention, attachment persistence, retry redesign,
new composer handoff contract, or structured bridge rejection protocol. Existing
queue ownership, storage, delivery uncertainty and cancellation behavior remain
unchanged. Implementation has not started.

## Observed problem and current code

The user reported Claude Code returning expired authentication. Local login
failed; restarting the harness put setup into `authenticationRequired`. The chat
still accepted input, showed it as Queued, and that apparent queued message was
absent after authentication and a settings round trip.

Code inspection confirms the prevention gap, not the exact reported timing:

- `shared/sesori_shared/lib/src/models/sesori/plugin_setup_response.dart` already
  reports ready, authenticationRequired, runtimeMissing, unavailable,
  notInspected and unknown. `plugin_management.dart` adds runtime state and
  safe action hints. No new wire field is needed.
- `client/module_core/lib/src/services/plugin_management_service.dart` owns
  management snapshots, bridge/connection fencing, change-event refresh and
  coalescing. Chats do not consume its `snapshots` stream.
- `SessionDetailCubit.sendMessage` and `_drainQueuedMessages` check connection,
  archive and attachment constraints, but not harness usability. Generic errors
  requeue locally. This plan prevents known-unavailable admission; it does not
  repair or redesign those error/queue paths.
- Shared `SessionDetailBody` selects read-only presentation only for route
  read-only mode or archive. Pending question/permission modal predicates also
  omit harness status.
- `PluginRuntime._acquire` already refuses setup-blocked, disabled, transitioning
  and unstartable harnesses. Reuse that authoritative bridge protection; do not
  add a second admission mechanism.
- Catalog session metadata is readable without a plugin, but message history
  calls the owning plugin. `SessionDetailLoadService` currently starts history
  before resolving metadata. A cold blocked chat therefore needs a reason-bearing
  shell, not a promise of newly cached/offline history.

## Required behavior

### One shared interaction decision

Resolve the actual session's plugin id against `PluginManagementService`;
never substitute the default harness or branch on a concrete harness name.

| Evidence | Behavior |
|---|---|
| Ready setup + dormant, starting, active or degraded runtime | Interactive. These are routable/on-demand or recoverable states; preserve normal startup and busy-session queuing. |
| Disabled runtime | Read-only: harness disabled. |
| Authentication-required setup | Read-only: sign in to this harness. |
| Runtime-missing setup | Read-only: harness runtime is not installed or cannot be found/used; show its safe action hint. |
| Unavailable setup, failed or blocked runtime | Read-only: harness unavailable, with supplied recovery guidance. |
| Stopping runtime | Temporarily read-only: harness is stopping. |
| Not inspected, unknown setup/runtime, or missing entry in a supported snapshot | Read-only: checking/not inspected/status unknown/harness unavailable, as appropriate. Never invent an authentication diagnosis. |
| Initial management load | Non-interactive checking state until evidence arrives. |
| First management load fails | Non-interactive unable-to-check state with Retry; not an endless spinner. |
| Retained supported snapshot with refresh failure | Keep the last-known decision and show a status-refresh warning. No new freshness timeout. |
| Management endpoint explicitly unsupported by a supported public old bridge | Keep existing interaction semantics with explicit update guidance: this bridge cannot report harness availability. Do not interpret a temporary request failure as endpoint absence. |

While connected, precedence is: unsupported endpoint; unresolved/loading;
load failure; exact session/plugin resolution; disabled runtime; non-ready
setup reason; ready + routable runtime; stopping; remaining blocked/failed/unknown
runtime. A retained refresh error does not override its supported snapshot.

Archive and route read-only restrictions remain independent and stronger than
an allowed harness. A known harness block cannot be bypassed by disconnecting;
on reconnect, do not reuse positive availability until the existing management
owner publishes current evidence. Otherwise preserve existing connectivity/offline
behavior rather than introducing a different connectivity policy.

### Presentation and actions

- Keep already rendered messages, selection/copy, scrolling and existing
  read-only navigation usable. Do not cover the transcript with an opaque or
  gesture-blocking overlay. Existing child-history links remain navigation.
- Remove active composer controls and show a persistent accessible notice naming
  the harness, the reason, and `Open Harness Settings`. Settings owns install,
  authentication, enable, restart and setup refresh; reuse those existing flows.
  Do not automatically log in, install, or launch a browser.
- Expose Retry for unavailable status/metadata checks. Recovery means reloading
  prerequisites and re-enabling interaction, **not recovering queued messages**.
- Disable all harness-mutating chat controls while blocked: send, text/voice
  input, attachments/paste/drop submission, slash commands, selection changes,
  stop and remote queued-prompt cancellation. Apply the same decision before
  cubit mutation methods, not only in widgets.
- Do not open question/permission response dialogs while blocked. Dismiss an
  already open dialog without responding when availability changes; retain
  pending data for the next authoritative refresh. Late voice/picker/dialog
  completion must not send after a block or widget disposal.
- A cold open with readable catalog metadata but inaccessible history shows a
  metadata-backed unavailable shell with the same reason and settings action.
  State honestly that history cannot currently be loaded. Do not fake an empty
  transcript or add transcript persistence. Returning to session/project lists
  remains possible; a cold shell need not reconstruct a child-history tree.
- Fresh usable status triggers the existing load/refresh path for history,
  options and pending interactions, then restores eligible controls without
  requiring route reopening. Unrelated harness changes do not reload the chat.
- Existing queued items are not moved, rewritten, relabeled as rejected, or
  recovered. Gate automatic queue draining while the harness is blocked; once
  usable, retain the existing queue policy. An explicit stop retains its current
  local-cancellation semantics if it was admitted while status was still usable.

### Honest detection boundary

This is a gate on known management state, not continuous credential validation.
Restart, setup refresh and management changes from another client update it
through the existing stream. A provider may discover expired credentials during
an admitted turn even when its setup probe reports ready. Preserve existing
backend error behavior; do not parse assistant error text, poll credentials,
add plugin-specific classifiers, or promise the UI can predict that failure.
Existing bridge admission still decides requests during the ordinary short
window before updated management reaches a client. No new queue behavior is
promised for that window.

## Ownership and implementation shape

### Shared client core

Add `SessionInteractionCalculator` in
`client/module_core/lib/src/services/session_interaction_calculator.dart` and
immutable foundation types in
`client/module_core/lib/src/foundation/models/session_interaction_state.dart`.
The calculator has no I/O, cache, subscription or mutable fields.

Use a sealed interaction value with available, checking, legacyUnverified and
blocked variants. Blocked carries a closed reason enum and nullable safe display
name/action hint. Keep an optional original management refresh error in the
immutable projection for diagnostics; presentation uses generic warning copy,
never raw error payloads. The decision table above is exhaustive; it must not
collapse unknown into ready.

`SessionDetailCubit` is the sole coordinator. Add one management subscription
to its existing subscription collection and carry the projection in existing
session state. Resolve from required named inputs: current session plugin id,
current management result, connection status and previous projection. Previous
state is used only to retain a known block through disconnect; current-connection
management supersedes it. Use existing connection-generation fencing, not a
second identity map/counter. Initial load and explicit Retry use the management
service's existing coalesced `refresh()`; do not refresh on every prompt/event.

For cold loading, split the existing `SessionDetailLoadService` workflow into
metadata and content phases, keeping the work in this existing owner:

1. Resolve catalog `Session` metadata first, with explicit found/waiting/failure
   outcomes. If session metadata cannot be established, keep a retryable metadata
   error; do not guess plugin identity or archive status.
2. The cubit computes interaction for that session. Checking/blocked produces a
   `SessionDetailState.harnessUnavailable` variant containing required `Session`
   metadata and the interaction projection, with no message/option/cursor fields.
3. Only an allowed or explicit legacy-unverified projection starts the existing
   parallel content/option reads. Pass resolved metadata to the service as a
   named input; it does not independently subscribe to management or calculate
   previous-state transitions. Update all internal callers together.
4. When applying an async result, consult the cubit's **current** projection and
   existing connection fence. A live block updates loaded state in place and
   preserves its transcript. A failed refresh never replaces a readable loaded
   transcript with the cold unavailable shell. Pagination retains its current
   error-preserving behavior and is not initiated while plugin reads are blocked.
5. A metadata-only shell does not declare unseen transcript content read. On
   availability restoration, use existing load/refresh orchestration to recover
   the view before enabling controls. Do not add a new lifecycle coordinator.

Keep existing archive checks; the metadata-backed shell carries the real Session
archive fact and has no mutating controls. This task does not redesign archive
state or catalog fallback behavior outside the required metadata-first gate.

Wire required collaborators in
`client/module_core/lib/src/di/cubit_composition.dart` through its existing
`createSessionDetailCubit` function and core DI. Do not duplicate dependency
composition in product shells or make cubits depend on other cubits.

### Shared presentation and shells

Modify shared `client/module_app_ui/lib/src/features/session_detail/`:
`widgets/session_detail_body.dart`, `session_detail_loaded_view.dart`, composer
controls, question/permission modal liveness predicates, and
`session_detail_presentation_scope.dart`. Add one shared reason/notice widget
and localized copy. Preserve the existing read-only view rather than creating
mobile and desktop policy variants.

Product shells only supply settings/navigation callbacks in
`client/app/lib/features/session_detail/session_detail_screen.dart` and
`client/desktop/lib/features/sessions/desktop_session_detail_screen.dart`.
Use the existing presentation scope and path/query params if focused harness
navigation is supported; no route `extra` state. Both use shared cubit composition.

`PromptInput` keeps its existing submission callback contract. When gating
changes touch an existing asynchronous voice/picker path, check mounted and
current interaction eligibility before effects. Do not introduce an awaited
handoff, change new-session creation, relocate `QueuedSessionSubmission`, extend
`ComposerDraftStorage`, or change the prompt queue's contents/ownership.

### Untouched areas

No bridge, concrete plugin, shared protocol, auth, encryption or database
production changes are expected. If inspection exposes a separate real backend
status bug, record it rather than silently widening this plan. Update verified
capability limitations in `docs/HARNESS_CAPABILITIES.md` only if new evidence
changes the documented detection claim.

## Fixed four-PR series

The user-approved scope reduction replaces the earlier six-step proposal before
any implementation PR began. Slug remains `harness-unavailable-chats`. Count
additions plus deletions, generated code and tests toward the 1,500-line soft cap;
if implementation cannot fit, revise the split/total before opening that PR.
The user explicitly approved a step-2 exception of approximately 1,750 changed
lines after focused verification: keep the coherent gate and required internal
API/test/generated updates together rather than add a prerequisite PR. The
four-step series and input-gating-only scope remain unchanged.

| Step and exact title | What / why | Risk and test focus | Expected result / estimate |
|---|---|---|---|
| 🌱 [harness-unavailable-chats] Plan read-only unavailable chats [step 1/4] | This plan and tracker; record prevention-only scope. | Low; documentation paths, titles and consistency. | No user-visible/database change; plan only. Approximately 350 documentation lines in the final plan/tracker. |
| ⚙️ [harness-unavailable-chats] Gate unavailable chats on both clients [step 2/4] | Shared availability projection, metadata-first blocked view, cubit action/drain guards, shared notice/dialog gating and shell settings callbacks. | Medium; management transitions, existing startup/queue policy, cold history, disposal, both surfaces. | Known unusable chats are read-only with clear guidance and automatically regain eligible controls. No database/wire/storage change. Approximately 1,750 changed lines including generation and tests (user-approved cap exception). |
| 🌿 [harness-unavailable-chats] Reconcile chat availability regressions [step 3/4] | Complete affected feature docs against delivered behavior and detection limits. | Low; accuracy of required behavior, failure signals and matrix. | No additional user-visible/database change; executable regression contracts. Approximately 100–200 lines. |
| 🌿 [harness-unavailable-chats] Verify read-only chats and retire plan [step 4/4] | Run the recorded matrix, record privacy-safe EVIDENCE.md and cleanup, retire only after passing. | Low implementation complexity; isolated setup/auth fixtures required. | Proven gate and recovery of interaction, not messages. No additional product/database change. Approximately 100–200 lines plus directory move. |

Step 3 is the penultimate documentation reconciliation explicitly supported by
`docs/regression/README.md` for durable planned work. Step 4 moves this directory
to `.plan/completed/` only when its recorded coverage passes. This plan PR does
not authorize implementing the successor without the user's implementation ask.

## Complexity budget and cleanup

- New persistent state: **none**. No wire change or compatibility migration.
- New mutable mechanisms: **one owned management subscription**. One immutable
  interaction projection is carried by existing cubit state; the existing
  management service and connection fences remain authoritative. No extra map,
  timer, registry, freshness counter, queue, retention quota or lifecycle owner.
- Observed safeguard: block input and queue draining when management already
  reports unusable. Ordinary reachable safeguard: close an open response dialog
  or reject a stale UI callback after another surface disables/restarts a harness.
- Accept bounded status propagation delays and backend limitations. Do not add
  admission-error protocols, credential watchers or queue recovery to eliminate
  every theoretical interleaving.
- Direct cleanup: compose existing archive/route-read-only predicates with the
  shared harness decision instead of repeating partial guards. Keep existing
  archive semantics, busy queues, stale-option handling and accepted-prompt
  reconciliation. No obsolete persisted/wire data was found; no broad refactor.
- No new analytics event: this is a correctness gate, not an adoption funnel.
  Existing accepted-submission analytics must not fire for a refused action.

## Verification and retirement

Highest required level: **targeted L4 Extended**, cumulative applicable L1–L4
entries in `docs/regression/plugin-setup-and-lifecycle.md`, `session-turns.md`,
`session-history-and-recovery.md`, and `questions-and-permissions.md`. Add focused
voice/attachment input-gating checks to their existing documents without expanding
this task into full voice/transcription or attachment-delivery certification.
Follow `docs/regression/README.md` proof boundaries; this is not a repository-wide
L4 campaign.

- **Automated core:** exhaustive setup/runtime/load-result precedence using
  backend-neutral fixtures, including missing entry, unknown values, retained
  refresh error and unsupported endpoint. Tests prove no enqueue/drain/stop/
  reply/selection mutation while blocked; reconnection cannot reuse another
  bridge's availability. Test metadata-first cold open, loaded-history retention,
  no falsely-read cold shell, recovery of controls, archive/read-only precedence,
  and unchanged dormant/degraded/busy queue behavior. No queue-recovery tests.
- **Shared UI and shells:** reason/action rendering, no active composer or
  response dialogs, live block during input/voice/attachment picker, late callback
  refusal, accessible notice, scrolling/copy/navigation, and settings callbacks
  on both mobile and desktop. Run directly relevant suites/analyzers; CI owns
  the full package matrix. Architecture review is scoped to the implementation
  diff, not an invitation to refactor existing queue/composer ownership.
- **Client E2E:** macOS desktop and one primary mobile platform (iOS), plus one
  representative Android unavailable→usable variation, against a macOS bridge.
  Mandatory observed journey: a real Claude Code test profile without valid auth
  → restart/refresh → read-only existing chat → settings authentication/refresh
  → enabled chat and successful new send. Use an isolated authorized profile;
  never revoke the user's normal credentials. Include cold blocked history.
- **Harness matrix:** every registered harness is represented in management
  listing/normalized-state automation. Shared gate rendering uses representative
  neutral state fixtures; it does not require bespoke production logic or live
  credential revocation for every plugin. Live coverage includes Claude for the
  reported auth flow, a representative managed runtime missing/restored, and one
  supporting ACP harness disabled/enabled. Verify a second harness remains usable.
  Record actual registered ids and fixture/runtime choices in evidence.
- **Adverse-state/multi-client:** disable/restart from the other surface while a
  chat or permission/question dialog is open; no response is sent. Exercise
  missing runtime, unknown/check failure, management refresh failure, reconnect,
  and a different bridge with the same plugin id. Restoration must not override
  archive/read-only routes or depend on reopening the screen.
- **Compatibility:** automated public-old-bridge management-endpoint absence and
  unknown enum fixtures, plus one supported old-bridge/new-client smoke if that
  public baseline exists. Record actual release evidence before asserting
  applicability; internal builds create no compatibility obligation. There is
  no new-client/old-client wire change to test on the bridge.
- **Not required:** queue/input restoration after navigation or process exit,
  outbox durability, new auth detection, packaged artifacts, stores, production
  analytics, alternate bridge OS or a full per-plugin/per-platform cross-product.

Evidence records Pass/Partial/Blocked/Fail, builds/accounts/platforms/harnesses,
first divergent boundary and cleanup, without raw credentials/prompts/transcripts.
Missing infrastructure is not a pass. Any reduction to this matrix requires
explicit user acceptance recorded here; otherwise the plan stays active.
Planning/docs-only changes need no Dart/Flutter test run.

## Review and scope decisions

Two architecture reviews of the earlier broader draft identified ownership and
contract gaps. Valid surviving guidance is incorporated here: one coordinator,
explicit metadata-before-history flow, UI-consumable refresh state, and shared
cubit composition. No approved verdict is claimed for this revised document.

PR feedback exposed the cost of recovery retention (bridge identity and aggregate
attachment memory). The user chose **input gating only**, superseding all recovery
storage, typed admission responses, asynchronous handoff and queue changes. Those
are removed, not deferred implementation requirements. No third architecture
review is needed merely to approve applied findings; implementation receives its
own scoped review. No implementation or live reproduction has run for this PR.
