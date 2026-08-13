# Session Turns

## Capability

Running a turn in an existing session: sending a prompt or slash command,
streaming output and status to completion, aborting a turn, and keeping prompt
defaults and queued client sends coherent.

## Required Behavior

- A prompt send targets one session with optional agent, model, and variant. A
  slash-command send completes on backend acceptance, not run completion, so no
  client request is held open for a whole agent run.
- Sends to an archived session are refused in the serialized lane archiving
  uses, so a send cannot slip past a concurrent archive.
- Work enters a short per-plugin admission lane in arrival order, then execution
  is serialized only per session family. Different families can execute
  concurrently on one plugin, and one slow session or plugin must not stall other
  sessions, other plugins, the relay read loop, or catalog reads.
- Streaming produces incremental message and part events and a terminal status
  transition back to idle; retry carries attempt, message, and timing, and
  finalized messages enter durable history matching a history read. Internal
  backend command records are not rendered as conversation messages or used as
  assistant model attribution.
- Prompt defaults update after a successful send and are published so other
  surfaces converge. Backend-originated mode changes such as an approved plan
  exit also persist and publish their effective defaults. A defaults-write
  failure must not fail the send. Abort stops the turn with an observable
  outcome and no completion notification, and the next turn starts without
  recovery output from the interrupted backend process.
- While the session-detail cubit remains alive, queued client sends preserve order,
  survive a transient disconnection, can be cancelled individually, and are never
  dropped. Each queued send retains the agent, model, and variant selected when
  it was submitted. A submitted prompt remains visible while the bridge is
  accepting it, including during a cold backend startup, and a failed acceptance
  returns it to the head of the queue. Queued and sending text render as the
  newest rows inside the scrollable transcript, never as controls pinned above
  the composer. It uses the same brand bubble and Markdown rendering as settled
  user text; a compact status rail and subtle queued outline carry the transient
  state, with the outline change animated when reduced motion is not requested.
  A turn started on one client is visible to every other client of that bridge.
- Live message envelopes render in transcript timestamp order even when events
  arrive out of order; late envelopes append after existing envelopes with the
  same timestamp rather than reordering an established turn. Finalized parts
  that arrive before their envelope are retained and reconciled without showing
  an empty user bubble or switching the composer to follow-up wording.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Live plugin, representative: a prompt streams assistant output and returns the session to idle. |
| L2 Routine | Live plugin, representative: slash command returns on acceptance; prompt defaults update; abort stops a turn and reports its outcome; finalized messages are immediately readable from history. |
| L3 Release | Client end to end (phone), every supporting production plugin: text, reasoning, tool, and status events stream with consistent normalization and the shared output bound; agent, model, and variant apply per send; streaming, composer, sending/queued feedback, and abort render. |
| L4 Extended | Relay integration, every supporting production plugin: a slow or unresponsive plugin leaves other sessions, plugins, and the relay responsive; archived sends are refused without racing archiving; disconnect and reconnect mid-turn resumes without lost or duplicated parts; queued sends survive in order while detail remains alive; a second client observes the same turn. |
| L5 Full | Client end to end, every supporting production plugin: retry status surfaces with attempt and timing; concurrent sends across sessions and plugins interleave without ordering damage; background and resume mid-turn recovers live state; an aborted turn triggers no completion notification. |

## Exploration Guidance

Vary prompt shape, prompt versus slash command, explicit versus default
agent/model, aborting early versus late, sending while busy to engage the client
queue, turn length, and client count.

## Failure Signals

- A slash command holds the client request open for the whole run, or a slow
  plugin blocks unrelated sessions, other plugins, or relay traffic.
- Streaming stalls, duplicates or loses parts, shows an empty user bubble, or
  orders a late envelope at the wrong transcript position; the session never
  returns to idle.
- Internal backend command records or synthetic model attribution appear in
  the conversation or replayed history.
- Prompt defaults regress, an approved plan exit does not restore Default
  across clients and restart, or a defaults-write failure fails the send.
- A send succeeds against an archived session, an aborted turn triggers a
  completion notification, or queued sends reorder, vanish, or resend while the
  session-detail cubit remains alive. Submitted text disappears while bridge
  acceptance or backend startup is still pending, or queued feedback uses a
  visually unrelated or composer-pinned surface, or renders authored Markdown
  as literal syntax.
- Recovery or interruption artifacts from an aborted turn appear in the next
  user turn.

## Known Limitations

- L3 and above need live backends; an omitted plugin is partial coverage, and
  client end-to-end coverage is phone-only.
- Session-detail refresh behavior is under active investigation, so refresh
  churn is recorded as evidence rather than judged pass or fail.
- The prompt queue is in memory and owned by session detail; leaving that surface
  disposes queued submissions rather than restoring them on reopen.

## Sources

- Bridge: `bridge/app/lib/src/bridge/services/` (prompt, abort, dispatcher,
  event, chat history), `lib/src/bridge/sse/`, and their tests
- Contract: `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart`;
  `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart`
- Client: `client/module_core/lib/src/cubits/session_detail/`,
  `client/app/lib/features/session_detail/`
- Plans (discovery only): `.plan/completed/relay-request-concurrency`,
  `internal-chat-history`, `.plan/active/session-refresh-reconnects`
