# Quota Auto Continuation

## Capability

Plugins report a terminal quota interruption with the visible error's identity,
original observation time, and either an absolute UTC reset or an explicit
unknown reset. The headless bridge persists session opt-in, exposes
`PATCH /session/auto-continuation`, and sends one ordinary `Continue.` after
a known reset plus two minutes. Phone and desktop chat share an inline opt-in
hint, a notice shown only while a continuation is due or needs explaining, a
quiet model-row chip while it is merely enabled, and a top-right menu toggle. Live
provider and platform verification remains in the
[active plan](../../.plan/active/quota-auto-continuation/PLAN.md).

## Required Behavior

- Existing visible error messages and their live/history IDs remain unchanged.
- Claude Code reports only a tagged root session-limit error followed by a
  failed, non-aborted result. Forwarded child errors and progress do not arm or
  replace root observations. Process-wide rate-limit frames alone do not report.
  Trailing stream frames preserve a complete error; a new root message clears it.
- Claude's recognized clock-time/IANA-zone format is accepted only when it
  denotes one future instant on the original local date. Stale times, unresolved
  day boundaries, malformed times, unknown zones and DST gaps/ambiguity remain unknown.
- Pi reports only recognized `openai-codex` assistant errors after native
  `agent_settled`. Intermediate `agent_end`, retry status and a subsequently
  successful response never report a terminal quota interruption.
- Pi's approximate retry minutes are anchored to the original error timestamp.
  Missing timestamps, absent resets, zero or malformed durations remain unknown.
- Stop/cancellation and process exit discard unsettled candidates. Each settled
  candidate is emitted at most once. History reads do not emit quota events.
- Core session-ID translation preserves the error identity. Internal quota
  events are never serialized as client SSE messages.
- Unverified harnesses advertise unavailable reporting. Generic 429s, billing,
  authentication and connection-reset text cannot infer a quota reset.
- Claude/Pi named-session readiness distinguishes idle from native retries,
  queued work and pending input. A recognized nonresident persisted session is
  idle without spawning a process; an unknown session is not evidence of idle.
  Other harnesses return unavailable readiness.
- Continuation storage keeps the session preference independent of its latest
  observation/outcome. Reset and pause deadlines survive a database reopen;
  a cancelled or consumed error cannot rearm on replay. A later error retains
  the session's preference. Session deletion cascades the record.
- Stale runtime generations cannot persist observations or cancel current ones.
  Due-record selection uses the caller's reset and pause cutoffs consistently
  for batch and named-session reads; repositories do not choose a retry policy.
- An omitted `Session.autoContinuation` remains unavailable to clients. Unknown
  future status/enum values decode conservatively. New bridge session responses
  and updates carry the durable preference and outcome. Enabling an unavailable
  harness returns 501; disabling remains possible. Repeating the same setting
  succeeds without another mutation.
- History-derived model/agent/variant defaults preserve the stored fast-mode
  preference; missing history selection falls back to stored defaults.
- Pi's history can record the native thinking level `off` for a model without
  a thinking selector. Restoring that default must still allow an ordinary
  prompt when native model discovery identifies it as non-reasoning, even when
  command discovery fails. Reasoning models still require an advertised level;
  an empty variant list after failed thinking discovery cannot establish `off`.
- The continuation resends the latest agent-authored message's agent without
  catalog filtering, so every plugin must record a selectable agent on its
  assistant and error messages. Claude records `Agent`; a quota error replayed
  from Claude history must be accepted as the continuation's selection.
- A single bridge timer checks due records every 30 seconds and on startup.
  Reset plus buffer, rather than time since observation, determines eligibility.
  A failed tick remains observable and rearms; disposal drains an in-flight tick.
- Readiness is checked before history and again before consuming the attempt.
  Busy, retrying, queued, pending-input, unknown and unavailable sessions pause
  for five minutes before rechecking; history failure also pauses. The latest
  history entry must still be the observed error.
- The attempt is persisted as consumed before ordinary prompt submission, with
  the existing selection preserved. Rejection does not retry. Failure to record
  acceptance leaves an unconfirmed attempt and cannot cause a duplicate send.
- Disable suppresses sending while preserving the observation. Manual send,
  Stop and archive durably cancel it before their primary operation; failure to
  save that cancellation blocks the action. A failed notification is logged and
  does not fail a successfully saved cancellation or its primary action.
- Quota observations and newer native user activity/default changes are awaited
  in the existing source-event order before a subsequent terminal handoff.
  Native prompt-default events remain internal; only committed defaults publish.
- Both chat controls use the same acknowledged setting request. While saving,
  controls are disabled and the last confirmed preference stays visible. A
  failure explains that the change could not be confirmed; it never invents a
  local schedule. Session updates from another client refresh the same view.
  An acknowledgement received during reload survives failed metadata/history
  reads and the unavailable-history shell; saving controls become usable again.
- A known reset offers opt-in; the scheduled notice shows the bridge's buffered
  date/time in the viewer's local zone and says the bridge must remain running.
- The card above the composer shows only for a known or unknown reset (offer
  or schedule), and, while enabled, for paused, unconfirmed, failed and unknown
  statuses. An enabled idle or already-submitted continuation shows no card:
  a quiet "Auto-continue" chip joins the composer's model row beside YOLO, with
  its label on pointer and only the clock on touch, and its anchored menu
  offers Disable (with the send time after a submission). Exactly one of the
  card and the chip is visible for an enabled preference.
- Unknown reset, paused, submitted, unconfirmed and failed attempts have distinct
  explanations. Unavailable harnesses cannot enable, but can disable an existing
  preference. An already-submitted prompt cannot be retracted by disabling.
- An older bridge without the view exposes an unavailable menu entry with an
  update explanation. Read-only and archived chats do not expose mutation controls.

## Coverage Worth Running

- **L1:** Claude/Pi quota mapper tests; their existing session-service suites;
  core session-event and SSE mapper suites. Include terminal failure, retry
  recovery/exhaustion/cancellation, forwarded subagents, original timestamps,
  stable IDs, missing resets and timezone ambiguity. The Claude plugin test
  sends a continuation with the selection replayed on a history quota error.
- **L1:** Shared continuation wire tests; bridge continuation repository and
  v17→v18 migration tests; session repository defaults tests. Cover actual file
  close/reopen, deduplication, preference retention, generation rejection, named
  versus batch cutoffs, and foreign-key deletion.
- **L1:** Pi prompt-selection tests restore `off` for a non-reasoning model
  through command-discovery failure while preserving variant validation for
  reasoning models and failed thinking discovery. Catalog refresh/reuse retains
  model capabilities with the corresponding options snapshot.
- **L2:** Pi managed-target and minimum-PATH RPC probes with a synthetic provider:
  terminal quota text with known/unknown resets, transient recovery and retry exhaustion must each end in
  exactly one final settlement. See the dated
  [evidence record](../../.plan/active/quota-auto-continuation/EVIDENCE.md).
- **L1/L2:** Scheduler, timer, mutation and route suites plus the composed bridge
  event/handoff test. Cover opt-in persistence, reset buffer, recheck backoff,
  disable/re-enable, future interruptions, normal prompt selection, durable
  cancellation failures, and consumed/unconfirmed attempts without resend.
- **L1:** Client service/cubit and shared notice tests: acknowledgement, failed
  mutations, legacy route errors, incoming session updates, unavailable disable,
  all outcome explanations, local dates, and enlarged text at narrow widths.
  The notice visibility table per status and preference, the chip menu's
  Disable and subtitles, and the phone body test's chip-to-card handoff.
  Phone and desktop screen tests exercise their actual top-right menu wiring.
- **L3 — live plugin:** For each advertised harness/provider case, use a naturally
  observed terminal quota and usable reset to verify opt-in → post-reset ordinary
  `Continue.` acceptance. Never deliberately exhaust an account. Synthetic
  protocol fixtures do not prove that the real provider recovers after reset;
  no suitable observation/account means this portion is blocked.
- **L3 — client end to end:** iOS simulator and macOS desktop each show opt-in,
  the acknowledged enabled/scheduled state, local date/time, menu, chip and inline
  disable, unavailable/unknown-reset explanations, and the ordinary user-message
  echo. One Android smoke checks the shared notice layout and menu wiring.
- **L4 — headless/relay recovery:** Run the real route, durable repository/DAO and
  normal prompt pipeline with controlled time. Two connected clients observe the
  same preference; disabling on one prevents the pending send. Closing all
  clients does not stop the headless scheduler. Restart/reconnect restore one
  eligible attempt; host wake catches an overdue attempt without a duplicate.
  Race due work with manual send, Stop, archive and disable. Pause on native
  retry/queued work, pending input or unavailable readiness, then recover.
- **L4 — compatibility:** A new client with an older released bridge shows an
  unavailable control without an enabled illusion; an older released client
  ignores the new view while ordinary send/Stop and error decoding still work.
  Use public-release wire fixtures, not an internal build as a compatibility
  baseline. Preserve unknown future status/enum decoding.

These levels are cumulative. Missing live-provider, relay or platform evidence
stays partial/blocked; a widget render or synthetic protocol result cannot be
reported as a client end-to-end or live-provider pass.

## Material Failure Signals

- A warning, retry, successful recovery or child error creates a root quota event.
- The observation references a different error ID than live/history projection.
- Redelivery moves a relative reset forward, or an ambiguous time becomes known.
- A cancelled turn leaves a candidate that a later result can publish.
- An internal reporting event leaks into client transport or sends without opt-in.
- A restart loses an opt-in or pause deadline, or replays a consumed observation.
- Non-idle/unknown readiness is treated as permission to send.
- A prompt is sent before the reset buffer, twice for one observation, or after
  disable/manual cancellation; failed acceptance recording causes a retry.
- History replay silently clears a session's fast-mode preference.
- A continuation is rejected as a stale selection because history recorded an
  agent the plugin does not accept.
- A failed setting request makes the UI appear enabled, a second client keeps
  stale state after a session update, or an unsupported bridge appears schedulable.
- A date is displayed in the wrong local day, pending input is shown as a ready
  schedule, or an unconfirmed/failed attempt is presented as a successful send.
- The card floats while nothing is due, a due/paused/failed state hides it, or
  an enabled preference shows neither the card nor the chip.
- The checked menu state cannot be disabled after support becomes unavailable,
  or archived/route-read-only chat surfaces expose mutation controls. An
  unavailable-harness chat must still allow disabling an existing preference.

## Harness Scope

See [Harness capabilities](../HARNESS_CAPABILITIES.md#quota-reset-auto-continuation)
for the current provider/format/version scope and unverified adapters.
## Related Coverage and Sources

- [Session turns](session-turns.md): ordinary prompt, Stop and pending input.
- [History and recovery](session-history-and-recovery.md): replay and reconnect.
- [Archiving and deletion](session-archiving-and-deletion.md): durable cancellation.
- [Plugin lifecycle](plugin-setup-and-lifecycle.md): readiness and generation fences.
- Bridge: `SessionContinuationService`, `SessionContinuationTimerListener`,
  `SessionContinuationRepository`, `SessionViewService`, the setting route and
  composed event/handoff tests under `bridge/app`.
- Client: `SessionAutoContinuationService`, `SessionDetailCubit`, shared
  `SessionAutoContinuationNotice`, `SessionAutoContinuationChip` and menu, with focused service/cubit/widget
  tests under `client/module_core` and `client/module_app_ui`.
