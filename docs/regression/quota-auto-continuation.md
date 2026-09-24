# Quota Auto Continuation

## Capability

Plugins report a terminal quota interruption with the visible error's identity,
original observation time, and either an absolute UTC reset or an explicit
unknown reset. Reporting is internal to the bridge. Scheduled sending and chat
opt-in controls are subsequent steps of the
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

## Coverage Worth Running

- **L1:** Claude/Pi quota mapper tests; their existing session-service suites;
  core session-event and SSE mapper suites. Include terminal failure, retry
  recovery/exhaustion/cancellation, forwarded subagents, original timestamps,
  stable IDs, missing resets and timezone ambiguity.
- **L2:** Pi managed-target and minimum-PATH RPC probes with a synthetic provider:
  terminal quota text, transient recovery and retry exhaustion must each end in
  exactly one final settlement. See the dated
  [evidence record](../../.plan/active/quota-auto-continuation/EVIDENCE.md).
- **L3:** Real provider account exhaustion on each supported production harness,
  then the eventual opt-in → reset → one scheduled `Continue.` journey. This
  remains required in later plan steps; synthetic protocol tests do not establish
  that end-to-end behavior.
- **L4:** Exercise the eventual scheduler through bridge restart, host sleep,
  recovery, concurrent manual actions, multiple clients and alternate platforms.
  These extended scenarios also remain pending the scheduler and client steps.

## Material Failure Signals

- A warning, retry, successful recovery or child error creates a root quota event.
- The observation references a different error ID than live/history projection.
- Redelivery moves a relative reset forward, or an ambiguous time becomes known.
- A cancelled turn leaves a candidate that a later result can publish.
- An internal reporting event leaks into client transport or schedules a prompt.

## Harness Scope

See [Harness capabilities](../HARNESS_CAPABILITIES.md#quota-reset-auto-continuation)
for the current provider/format/version scope and unverified adapters.
