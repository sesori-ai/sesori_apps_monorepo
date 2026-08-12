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
  dropped. A turn started on one client is visible to every other client of that bridge.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Live plugin, representative: a prompt streams assistant output and returns the session to idle. |
| L2 Routine | Live plugin, representative: slash command returns on acceptance; prompt defaults update; abort stops a turn and reports its outcome; finalized messages are immediately readable from history. |
| L3 Release | Client end to end (phone), every supporting production plugin: text, reasoning, tool, and status events stream with consistent normalization and the shared output bound; agent, model, and variant apply per send; streaming, composer, queued sends, and abort render. |
| L4 Extended | Relay integration, every supporting production plugin: a slow or unresponsive plugin leaves other sessions, plugins, and the relay responsive; archived sends are refused without racing archiving; disconnect and reconnect mid-turn resumes without lost or duplicated parts; queued sends survive in order while detail remains alive; a second client observes the same turn. |
| L5 Full | Client end to end, every supporting production plugin: retry status surfaces with attempt and timing; concurrent sends across sessions and plugins interleave without ordering damage; background and resume mid-turn recovers live state; an aborted turn triggers no completion notification. |

## Exploration Guidance

Vary prompt shape, prompt versus slash command, explicit versus default
agent/model, aborting early versus late, sending while busy to engage the client
queue, turn length, and client count.

## Failure Signals

- A slash command holds the client request open for the whole run, or a slow
  plugin blocks unrelated sessions, other plugins, or relay traffic.
- Streaming stalls, duplicates parts, or the session never returns to idle.
- Prompt defaults regress, or a defaults-write failure fails the send.
- A send succeeds against an archived session, an aborted turn triggers a
  completion notification, or queued sends reorder, vanish, or resend while the
  session-detail cubit remains alive.

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
