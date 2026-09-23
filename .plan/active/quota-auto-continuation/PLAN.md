# Quota auto continuation

Status: planning; implementation has not started. Research: 2026-09-23.

## Goal and agreed scope

Let a user opt an individual session into automatically sending **Continue.**
after a provider quota resets. The preference stays enabled for later quota
interruptions in that session until the user disables it. Global preferences,
automatic model switching, and configurable prompts/delays are outside v1.

The user explicitly requested both an inline chat hint and an enable/disable
configuration in the chat screen's top-right three-dot menu. Both control the
same bridge-owned setting. Apply this across every harness whose driven seam
can provide a trustworthy quota interruption and reset time; provider/model
limitations must remain visible.

This plan PR documents the design and evidence. It does not ship the feature or
authorize an assertion that any harness already supports Sesori scheduling.

## User experience

1. Default off for every session. A detected current quota interruption with a
   known reset shows **Enable auto continuation** beside a short explanation.
2. The chat overflow menu includes **Auto-continue after quota resets**, with its
   current checked state. It can enable the preference before the next quota
   interruption and can always disable an already-enabled preference.
3. Enabling while blocked schedules one continuation at **reset + two minutes**.
   This fixed buffer is a proposed v1 default. Display an absolute date/time in
   the viewing client's time zone, including the date for waits crossing days.
4. While scheduled, show **Auto continuation on · Continues at …** and a
   **Disable** action in the chat. When enabled without a scheduled attempt,
   show a compact **Auto continuation on** indicator. Do not show busy/retrying
   for an hours-long quota wait; existing native retry presentation is separate.
5. Disabling cancels the pending automatic send. State comes back from the
   bridge and updates all connected clients; failures must not look successful.
   If sending was already accepted, report that disabling affects future sends.
6. Unknown reset: show **Quota reached; reset time unavailable. Auto continuation
   cannot be scheduled.** Keep any enabled preference for future supported
   errors. An unsupported/unverified harness gets an explanatory unavailable
   control, while an existing enabled preference remains disableable.
7. At the scheduled time, send the ordinary text prompt **Continue.** through
   the normal session prompt path, using that session's current prompt defaults
   and existing permission policy. Its normal user-message echo appears in chat.
   Preserve the provider's original quota error text.
8. Successful submission leaves the preference on. A later terminal quota error
   with a newly reported usable reset schedules another attempt. A failure with
   no usable reset stops scheduling and remains visible; never poll by sending
   repeated prompts against an unknown or already-consumed reset.

The bridge must be running and able to route the session to send. Phone/desktop
closure does not cancel a wait. Sleep or a bridge restart can delay the attempt
until the bridge is available again; the UI must not promise execution while
the host is asleep or the harness is unavailable.

## Evidence and current code

[EVIDENCE.md](EVIDENCE.md) separates local observations, source contracts, and
unverified harness/provider combinations. The capability audit also lives in
[the harness matrix](../../../docs/HARNESS_CAPABILITIES.md#quota-reset-auto-continuation).

- Claude local error records contain a clock time plus an IANA time zone.
  `claude_stream_message.dart` already parses `rate_limit_event`; the dispatcher's
  switch discards `ClaudeRateLimitMessage`. Native `api_retry` is already mapped.
- Pi local `openai-codex` error records include a relative reset duration, and
  others omit it. `PiHistoryMapper._assistantInfo` preserves error text.
  `PiEventDispatcher` already owns `auto_retry_start/end` and settled events.
- Codex rollouts expose structured account reset timestamps. Sesori's terminal
  error tests cover `usageLimitExceeded`, but do not establish a reset binding.
  The app-server's account rate-limit response is a candidate source, not proof
  that every failure or selected model has the same exhausted bucket.
- `BridgeSseSessionError` currently carries only a session ID. Plugin and shared
  error messages carry presentation text; session status has idle/busy/retry.
  None currently represents a quota continuation setting or pending send.
- `SessionPromptService` already owns accepted prompt IDs, normal dispatch,
  prompt defaults, and archived-session validation. `SessionOperationDispatcher`
  serializes session mutations. Reuse those owners, including their existing
  scope; do not introduce another family lock or scheduler-owned prompt route.
- The existing overflow is composed in shared
  `session_detail_body.dart`; mobile supplies entries via
  `session_detail_screen.dart` and `SessionListActionDispatcher`. Put the new
  chat setting in shared chat composition with business state in `module_core`,
  so mobile and desktop use the same action without adding it to unrelated list
  menus or making shells responsible for scheduling.

## Architecture and ownership

[IMPLEMENTATION.md](IMPLEMENTATION.md) is part of this plan. It names the
workspaces, proposed files/classes, dependencies, wire/storage contracts,
trigger adapters, and ordered data flow. Names are proposed new code,
not claims that those classes already exist.

### Plugin boundary

Introduce a small typed internal quota-interruption event in
`sesori_plugin_interface`, emitted only for a **terminal quota-blocked turn**.
Its payload names the backend session, a stable error/turn observation ID, its
observation time, and a sealed reset result: known UTC instant or unknown.
The observation ID is the terminal `PluginMessageError.id` used by history
and live projection, so a due-time read can identify the same interruption.
Parse provider strings/codes and timestamps in the owning plugin. No provider
error matching, account credentials, or harness IDs belong in core or clients.

Keep this distinct from idle, transient retry, authentication, billing/credit
exhaustion without a reset, transport failure, and quota warning notifications.
It is not a new variant of the existing wire `SessionStatus` union. Preserve
the existing error and idle events for old clients. Do not make history reads,
catalog imports, or scrolling past an old error emit scheduling events.

Use an explicit plugin-declared reporting capability, surfaced through a typed
session view. It means **conditional reset reporting**, never universal model
support. Update all internal implementors together; a plugin with no verified
reset signal does not advertise availability. A particular error can still
have an unknown reset on a capable plugin.

The descriptor also declares that capability without starting the runtime.
Supported plugins implement a named-session readiness operation with explicit
idle/busy/retrying/queued/awaiting-input/unavailable/unknown results. Generic
status-map omission cannot mean idle: Claude/Pi resident maps omit sessions
after restart. Native readiness stays plugin-owned and must cover that flow.

Required supported-source work:

- **Claude:** prefer `rate_limit_info.status == rejected` and `resetsAt`, correlated
  with the stopped turn, not a warning or an account-wide announcement alone.
  Use the locally observed, tagged `rate_limit` error's time/zone as a narrowly
  tested fallback. Anchor a time-only reset to the error's date and named zone;
  handle day rollover/DST or report unknown instead of guessing. Keep this
  parsing inside Claude. Retain at most one candidate in existing turn state.
- **Pi:** on the final failed/settled turn, parse recognized `openai-codex` quota
  errors with an explicit duration. Convert duration relative to the original
  error timestamp, once. Prefer structured provider diagnostics if the pinned
  RPC payload exposes them. Generic usage-limit and connection-reset strings
  are not sufficient. Native retries finish before Sesori can arm.
- **Codex:** bind a terminal `usageLimitExceeded` to the current applicable
  exhausted bucket(s). Read the existing app-server account limit API on that
  failure if necessary; no account-wide polling. When multiple applicable
  windows block the same request, use the latest required reset. If the bucket
  cannot be attributed or a blocking window lacks a reset, emit unknown.
- **Other registered harnesses:** inspect the actual driven error payload and
  native retry ownership in step 2. Implement any evidenced provider/reset
  combination in its plugin; generic ACP error extensibility or a 429 alone
  does not establish support. Record an unverified limitation honestly rather
  than declaring the harness incapable. OMP's ACP transport does not inherit
  Pi RPC support merely because the projects are related.

### Durable bridge state

Admit a **fresh** known reset only when it is strictly after its original
observation timestamp. Zero/negative durations, invalid timestamps, and stale
past resets become unknown. Re-reported stale resets cannot produce a loop of
new attempts. A persisted reset that was valid when observed remains eligible
after its deadline passes during sleep/restart.

The bridge is the single scheduler and settings authority. Add one session-owned
record (one row per opted/observed session, foreign-keyed to the session) via an
API/DAO and repository. A missing row means disabled with no observation; no
historical transcript backfill is required. Persist:

- the enabled preference, independent of the current interruption;
- one sealed current outcome: no observation, reset known, reset unknown,
  consumed observation, failed automatic submission, or paused known reset.
  Paused preserves its observation/reset and bounded reason for the next check.
  Each variant owns only
  its valid required fields. Known reset includes observation ID/time and reset
  time; consumed preserves the observation ID to avoid rearming the same event;
  failed submission retains a bounded failure reason and the consumed ID.

Do not independently persist a countdown, a second copy of reset + buffer, or a
list of jobs. Scheduled status is derived from enabled + known reset. The same
record supports reconnect reads and bridge restart; deleting a session deletes
its record. Disabled observations are harmless and permit an explicit later
enable against the currently detected blockage.

A bridge service owns policy. Two thin trigger adapters (normalized quota
events and due-time ticks) feed it, composed in `bridge/app/lib/src/orchestrator.dart`.
The event listener owns one ordered subscription to the existing normalized
source; its peer timer listener owns **one 30-second timer**
for due records, not a timer/map per session. A non-overlapping self-rescheduling
tick invokes the service, then schedules its next tick. Persist normalized live
quota observations through the existing event consumption path after identity
translation and generation validation. Broadcast changes through the current
session-update stream; SessionViewService supplies the same view after reconnect.

### Dispatch and cancellation

Add a narrow automatic-send entry to the existing prompt service. It enters the
existing operation dispatcher once, validates/consumes the named observation,
then calls the existing internal send body. Do not nest dispatcher calls.

Inside that lane, require that the setting is still on, the same reset is due,
the session is promptable and idle, and native retry/queued user work is not in
progress. Use existing status/queue authority. Persist consumption **before**
calling the harness, so a restart cannot blindly resubmit an uncertain send.
Use the accepted-prompt ID mechanism already owned by `SessionPromptService`.

Before consuming a due observation, read only that named session's current
snapshot via `SessionRepository.getSessionMessages` and the plugin-owned
`getQuotaContinuationReadiness` wrapper. The last conversation
message must still be the stored terminal error ID. Existing snapshots return
the session history rather than a tail page: make one read per due attempt and
inspect its tail. Add no history pagination, recursive child reads, account
scans, or replay system. A newer message consumes the obsolete wait.
Uncertain current state persists a paused view instead of sending. This handles native activity
while the bridge was offline without a restart cache or startup-wide sweep.

This is one automatic submission attempt per observation, not an exactly-once
distributed delivery claim. A crash between durable consumption and backend
acceptance can miss one continuation. Leave that observation consumed and make
the uncertain attempt visible after reconnect; a user can continue manually.
Do not add an outbox, lease registry, or speculative backend reconciliation.

Ordinary reachable flows to handle at existing authoritative seams:

| Flow | Required behavior and owner |
|---|---|
| Disable from either client while waiting | Same dispatcher orders setting change against send; disable first prevents submission. |
| User submits a new prompt/command or changes the effective selection | Consume the old wait when the accepted operation supersedes it; keep preference on. Use existing prompt/default-change authority. |
| User presses Stop | Cancel that pending wait through abort authority; keep preference on for future quota interruptions. No delayed surprise restart of the stopped turn. |
| Archive/delete | Existing session mutation authority cancels/removes the wait; never reopen an archived/deleted session. |
| Native turn resumes or queued work runs | Invalidate the old wait from authoritative new activity; do not append Continue behind active work. |
| Host sleeps/restarts | Re-read durable due work on availability; dispatch only if the same observation is still current and session is idle. |
| Harness disabled/unavailable or permission/question still pending | Show paused/unavailable; no forced harness enable, permission approval, or automatic queue insertion. Reuse current routing/request state. |
| Submission rejected or reset unavailable | Surface/log failure; no prompt retry loop. A fresh terminal quota observation may establish a later schedule. |

Only named-session state is added. Existing family serialization remains, but
this feature adds no parent/child cascade, family inspection, or account-wide
coordination. Independent enabled sessions may each continue after the same
reset; account-level fairness and staggering are outside v1.

### Client contract and compatibility

Expose a shared typed session continuation view and a typed enable/disable
request via one session route, using API -> Repository -> Service -> Consumer
in `module_core`. Shared chat widgets consume cubit state and call that service.
The bridge owns derived scheduling status; clients only format times.

New optional wire fields must decode omission from a publicly released older
peer honestly as feature unavailable. An older bridge's unsupported route must
not leave a locally enabled switch. Older clients ignore the additive session
view and keep their existing error/idle presentation. Follow dated compatibility
markers using the current product version at implementation. Internal plugin
contracts have no compatibility shims. A new table migration creates this new
feature's storage; it does not reconstruct old quota interruptions.

### Complexity budget and accepted limits

New durable state: **one record per affected session**, with preference and one
sealed observation/outcome. New long-lived runtime state: **one timer and its
ordinary lifecycle flags**, plus **one normalized-event subscription** owned
by its peer listener. Publication reuses the existing mutation stream.
Claude/Pi may retain **one candidate inside existing active-turn state each** to
wait for terminal settlement. Codex uses a failure-triggered read, not a new
account cache. No per-session timers, second prompt queue, general job system,
distributed leases, watchdog process, or client background execution.

Safeguards above address observed multi-day waits and ordinary manual actions,
native retries, multiple clients, and restarts. The accepted crash window can
miss one send; unfamiliar/localized error formats can be unschedulable; imported
pre-feature errors are not automatically armed. Do not add machinery to erase
these bounded limits. If implementation exceeds this state budget, reconsider
the owning seam before adding coordination.

Analytics assessed with `.opencode/skills/add-analytics/SKILL.md`: no new v1 event
is planned. Client observations cannot authoritatively count headless resumes,
and no reporting consumer has been selected. Keep operation context, original
errors and stacks in local logs; do not copy prompts into diagnostics.

Cleanup assessment: no existing scheduler or setting becomes obsolete. Preserve
native retry/error rendering. Remove Claude's intentionally ignored rate-limit
dispatch branch when its replacement lands; update stale capability claims and
tests alongside it. No unrelated architecture refactor is planned.

## PR sequence

All steps use slug `quota-auto-continuation`, in this order, total **6**. Estimates
are authored additions + deletions; measure complete merge-base churn including
generated files before each push and split cleanly if needed.

| Step | Exact proposed title | Deliverable / expected result | Risk and validation |
|---|---|---|---|
| 1 | 🌱 [quota-auto-continuation] Plan per-session quota recovery [step 1/6] | This plan, evidence, tracker, capability audit. No product/database change. | Documentation links, factual boundaries, architecture plan review. |
| 2 | ⚙️ [quota-auto-continuation] Normalize terminal quota reset signals [step 2/6] | Internal typed event/capability and verified plugin implementations; current errors still render. No scheduled sends or database change. Estimate 600–1,000 authored lines. | Parser/dispatcher tests for each supporting seam, unknown/no-reset/false-positive/native-retry cases; analyze touched packages; matrix updated with actual evidence. |
| 3 | 🚧 [quota-auto-continuation] Persist and dispatch session continuations [step 3/6] | Session state, shared view/route, scheduler and cancellation integration. Opt-in headless API works; new session-owned storage. Estimate 650–1,000 authored lines. | Focused DB, service, route, ordering, restart, old-peer serialization tests; headless integration. Generated Drift/Freezed churn may exceed cap: report it separately and keep it with source. |
| 4 | ⚙️ [quota-auto-continuation] Add chat auto-continuation controls [step 4/6] | Shared hint, enabled indicator, scheduled time and overflow toggle on mobile/desktop. No new database change. Estimate 350–650 authored lines. | Cubit/service and widget behavior; client end-to-end toggle, disable, reconnect and scheduled echo. |
| 5 | 🌿 [quota-auto-continuation] Reconcile quota recovery regression coverage [step 5/6] | Complete feature docs and final support matrix, including provider limitations. No product/database change. | Links and consistency with shipped behavior and actual test coverage. |
| 6 | 🌿 [quota-auto-continuation] Verify quota recovery and retire the plan [step 6/6] | Run the matrix below, record results, move plan to completed only when it passes. No intended product/database change. | L4 accumulated coverage through complete authoritative boundaries; partial/blocked stays active. |

Each production step is independently compilable. Review architecture-bearing
production diffs using the repository review skills. Update regression docs
when behavior lands in steps 2–4; step 5 reconciles them, not their first draft.

## Verification and retirement

Highest required level: **L4**, cumulative within the affected feature scope.
No packaged distribution or new external-service behavior is delivered.

Affected documents: `docs/regression/session-turns.md` (primary),
`session-history-and-recovery.md`, `session-archiving-and-deletion.md`,
`plugin-setup-and-lifecycle.md`; add a dedicated quota document only if the
primary document becomes unwieldy. Update `docs/HARNESS_CAPABILITIES.md` per
supported harness/provider, without model-name allowlists in shared code.

| Boundary | Required evidence |
|---|---|
| Automated, every implemented plugin parser | Real sanitized error fixtures; absolute/relative reset conversion, timezone/date/DST, missing fields, generic connection reset, generic 429, warning/billing/auth errors, malformed/past reset, and native retry exhaustion. Replayed history never arms. |
| Automated/headless bridge, representative plugin | Off by default; enable during wait; future interruptions; reset + buffer; one send per observation; same-observation replay; disable/manual send/Stop/archive/delete; persistence; failure; host clock passed while asleep. Exercise actual routes, DAO and normal prompt service with controllable time. |
| Live plugin, every declared supporting production harness/provider seam | Prove the pinned runtime's raw quota payload reaches its parser and that an ordinary Continue is accepted in that session. Existing captured real quota payload plus controlled protocol replay can prove the hours-long wait; label replay explicitly. Actual post-reset recovery remains required wherever provider behavior itself is claimed. Do not spend tokens to deliberately exhaust quotas. |
| Client end to end | iOS simulator and macOS desktop against one representative supported bridge/plugin: inline enable, three-dot enable/disable, scheduled local time, enabled idle indicator, unknown/unavailable state, actual user-message echo. One Android shared-UI smoke for menu/notice layout and action wiring. |
| Relay/multi-client | Two clients on the same bridge observe the same setting; disable from one prevents the other's pending send. Closing all clients still allows one bridge send. Reconnect/restart restores state. |
| Compatibility | New client/older released bridge reports unavailable without a local enabled illusion; older released client/new bridge keeps error/session decoding and ordinary send/Stop. Fixtures must correspond to the public release baseline. |

Fixtures prove parsing and time policy, not provider recovery. A missing account,
runtime, client platform, or natural quota observation is **Blocked/Partial**,
never a pass. Record concrete versions and boundary results in the tracker.
Any reduction to this recorded matrix requires explicit user acceptance here
before retirement.

## Plan review

The first review rejected the draft at its specificity gate. The clarified
review passed that gate and returned architecture findings. Applied directly:
explicit paused/readiness contracts, exact prompt-default mapping, no-dispatch
cancellation, peer trigger lifecycles, Layer 3 session-view composition,
service-owned cutoff calculation, and repository-owned generation fencing.
The corrected version was not re-reviewed, following the plan-review rule.
No production work has started.
