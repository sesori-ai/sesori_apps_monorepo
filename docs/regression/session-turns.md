# Session Turns

## Capability

Running a turn in an existing session: sending a prompt or slash command,
streaming output and status to completion, aborting a turn, and keeping prompt
defaults and queued client sends coherent.

## Required Behavior

- A prompt send targets one session with optional agent, model, and variant.
  Prompt and slash-command sends complete on acceptance — durably enqueued by
  the plugin or taken by the backend — never on run completion, so no client
  request is held open for a running or queued agent turn. Acceptance while
  another turn runs therefore returns in sub-seconds, and session-lane
  operations queued behind a send (abort, permission and question replies)
  are never blocked for the duration of a turn.
- Every send carries a client-generated prompt id, stable across retries. A
  queue-owning plugin refuses a duplicate id (already queued or within its
  bounded recently-dispatched window) as an idempotent success, so a retry of
  a send whose response was lost does not become a second turn within that
  window.
- Sends to an archived session are refused in the serialized lane archiving
  uses, so a send cannot slip past a concurrent archive.
- Work enters a short per-plugin admission lane in arrival order, then execution
  is serialized only per session family. Different families can execute
  concurrently on one plugin, and one slow session or plugin must not stall other
  sessions, other plugins, the relay read loop, or catalog reads.
- Streaming produces incremental message and part events and a terminal status
  transition back to idle; retry carries attempt, message, and timing and
  returns to busy as soon as the retried request streams output again, and
  finalized messages enter durable history matching a history read. A terminal
  provider failure appears as an inline error message and remains visible after
  refresh or reopen. Backend-provided message timestamps remain present through
  live updates and durable-history reloads, using the backend's authoritative
  source for each path. Internal backend command records are not rendered as
  conversation messages or used as assistant model attribution.
- Claude user prompts appear in the live transcript from the CLI's replayed
  stdin echo under their transcript uuid, so a follow-up prompt stays visible
  and a later transcript backfill converges on the same message instead of
  duplicating it. The bridge worktree context envelope is stripped from the
  echo, and a slash command renders one synthetic user message because its
  echo is the CLI's internal command envelope.
- Codex user prompts use the same visible content live and after rollout replay:
  the bridge worktree context envelope is hidden, authored text remains, and
  bounded inline images render as file parts. An attachment-only initial prompt
  therefore remains visible without exposing the generated context.
- A plain Claude prompt sent while its resident process is working is written
  immediately with `priority: next`. Claude absorbs it at the next tool
  boundary when possible, within the active agent turn; otherwise Claude keeps
  it for its own following turn. Several absorbed prompts may share one result,
  while a prompt that starts later settles on that later result. Slash commands
  and model, effort, or permission-mode changes wait for a turn boundary
  instead of changing the active turn.
- Pi keeps at most one lazy resident RPC process per active session and allows
  different sessions to run concurrently. Startup replays and hydrates message
  identity before live frames attach or a turn dispatches; same-session prompts
  remain FIFO. An accepted prompt remains bridge-queued through startup and
  selection until Pi echoes its correlated user message, including an
  attachment-only echo; it can be cancelled before dispatch, and its
  undispatched prompt id remains immediately retryable while cancellation
  settles. If a successful turn omits that echo, Pi maps the stored payload
  through the same user-message path before clearing the queue. Process exit
  settles current work before queued work reconnects.
- Pi slash commands are accepted by their correlated response or a matching
  extension dialog and remain in the request's sending state until then rather
  than exposing a cancellable bridge-queue entry. Commands reject while that
  session is busy, and a successful command with no agent run crosses `get_state`
  before returning the lane idle.
  Abort rejects queued work and replaces the process so hidden steering or
  follow-up input cannot leak into the next turn.
- Pi accepts only bounded, valid inline GIF, JPEG, PNG, and WebP data. Paths,
  URLs, non-image data, malformed base64, and oversized images fail visibly
  before admission and are never fetched, stringified, or silently omitted.
- Pi discovers models, thinking levels, and extension, prompt-template, prompt,
  and skill commands through bounded approved no-session probes in normalized
  project directories. Reuse is project-local, refresh always probes, concurrent
  requests for one project coalesce, and a failed refresh never replaces the
  last coherent snapshot. Dialogs raised during probes are cancelled and never
  enter session UI state. Empty Pi sessions remain lazy until their first prompt
  or command. Creation is published before any buffered turn output. Imported
  parent forks preserve exact lineage. Deleting a root fences descendant work
  and dialogs but physically removes only the named root session artifact.
- Hermes runs turns through ACP v1 over `hermes acp`: initialization uses the
  first non-terminal provider authentication method, image prompt parts remain
  available, streamed updates use the shared ACP normalization, and abort uses
  session cancellation. Available models come from Hermes's ACP session model
  state, and the selected exact model ID is applied through Hermes's
  `session/set_model` extension before each changed-model turn. A rejected model
  fails before prompting. Completed assistant text is finalized at each tool
  boundary, so earlier prose in a multi-tool turn does not depend on the final
  turn snapshot. Sesori does not call form-elicitation or unadvertised
  session-close methods to complete an ordinary turn.
- Existing-session ACP prompts remain bridge-queued while an earlier same-session
  turn, declared process-wide lane, resume, or selection blocks their
  `session/prompt` frame. Their synthetic user transcript message is published
  only after that frame flushes successfully to the agent's stdin. Follow-up and
  replayed user messages preserve ordered text and bounded data-backed image
  parts, including attachment-only prompts. Initial projection contains only
  normalized user-visible text plus those images; injected context, local paths,
  and URLs remain absent. OMP runs different sessions concurrently because its
  permission and form requests carry explicit session IDs. Within one OMP
  session, it preserves active-prompt replacement by cancelling the active turn
  immediately, then dispatching the newly queued input after cancellation
  settles; Cursor and Hermes retain ordinary FIFO turn boundaries.
- Normalized user-message events feed the durable user-side activity marker used
  to order running roots. Known event times are applied monotonically. Backend
  input represented as a user message, including automatic compaction or other
  generated input, can therefore count; the marker does not claim perfect human
  provenance.
- Prompt defaults update after a successful send and are published so other
  surfaces converge. Backend-originated mode changes such as an approved plan
  exit also persist and publish their effective defaults. A defaults-write
  failure must not fail the send. Abort stops the turn with an observable
  outcome and no completion notification, and the next turn starts without
  recovery output from the interrupted backend process.
- Opening an existing session selects valid persisted prompt defaults first and
  otherwise continues with the latest assistant/error transcript model before
  falling back to agent or catalog defaults. The transcript model remains
  authoritative when a retained provider cache does not list it, so a terminal-
  imported session cannot silently resume on a different provider.
- The bridge owns accepted-but-not-yet-visible prompts. An entry appears in the
  session snapshot and full-list `session.queued-prompts` events, survives
  leaving the screen, locking the phone, and reconnecting, and is visible to
  every client of that bridge. A normal Claude prompt usually dispatches as
  steering immediately and remains represented only until its replayed user
  message lands; Pi similarly remains represented until its correlated echo.
  Entries still waiting for process startup, an earlier turn or command, or a
  selection boundary can be cancelled individually; cancellation after dispatch
  is refused as benign because the prompt is then governed by Stop. Aborting the
  session clears every remaining plugin-owned entry.
- One prompt renders as one bubble that transforms in place: sending (staged
  locally while the POST is in flight) → queued (bridge-owned) → sent (the
  transcript message). The dispatched message carries the prompt id and
  replaces the queued entry in the same client state emission, so no frame
  shows the prompt twice or not at all. Client-staged sends preserve order,
  survive a transient disconnection while the session-detail cubit is alive,
  retain the agent, model, and variant selected at submission, and drain with
  the same prompt id so retries stay idempotent.
- When a plugin rejects a send before acceptance because its agent, model, or
  variant is no longer offered, the bridge deletes that options-cache row and
  returns the typed `staleSessionOptions` rejection. The client force-refreshes
  the options, replaces only unsupported queued selections without changing
  FIFO order or prompt ids, warns the user, and retries once. A failed refresh
  or second stale rejection leaves the prompt visible and queued instead of
  disappearing or entering a retry loop.
- Each plugin stamps that prompt id onto the user-message echo of its own
  dispatch, using the link its backend exposes — Claude's queue entry, ACP's
  accepted send, Pi's dispatcher, Codex's client-supplied identifier, and
  OpenCode's server-reserved ordered message identifier that the bridge reuses
  for the real dispatch. OpenCode applies the same correlation to prompts,
  slash commands, and manual compaction. Compaction renders only the user-entered
  command arguments; bridge-authored guidance remains backend-only. A message
  authored in the backend's own UI carries no prompt id and renders as an
  ordinary transcript message. A harness that publishes no user echo at all
  leaves the client's own copy to be settled by the next snapshot instead.
- Queued and sending text render as the newest rows inside the scrollable
  transcript, never as controls pinned above the composer. They use the same
  brand bubble and Markdown rendering as settled user text; a compact status
  rail and subtle queued outline carry the transient state, with the outline
  change animated when reduced motion is not requested. A turn started on one
  client is visible to every other client of that bridge.
- Live message envelopes render in transcript timestamp order even when events
  arrive out of order; late envelopes append after existing envelopes with the
  same timestamp rather than reordering an established turn. Finalized parts
  that arrive before their envelope are retained and reconciled without showing
  an empty user bubble or switching the composer to follow-up wording.
- Transcript content scrolling behind the top navigation or floating composer
  dissolves into a strong surface-colour fade, keeping the title and controls
  visually separate and screenshot-readable without text collisions.
- A leftward touch, stylus, or trackpad drag across the transcript reveals all
  message timestamps together without changing vertical scroll or follow state,
  then settles closed on release. System-back edges remain reserved on iOS and
  Android gesture navigation, mouse drags remain available for text selection,
  and a horizontal drag inside a fenced code block scrolls only that block.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Live plugin, representative: a prompt streams assistant output and returns the session to idle. |
| L2 Routine | Live plugin, representative: slash command returns on acceptance; prompt defaults update; abort stops a turn and reports its outcome; finalized messages are immediately readable from history; a recognized stale option returns the typed rejection only after cache invalidation. |
| L3 Release | Client end to end (phone), every supporting production plugin: text, reasoning, tool, and status events stream with consistent normalization and the shared output bound; agent, model, and variant apply per send; streaming, composer, sending/queued feedback, and abort render; a stale selection refreshes, warns, and retries once without losing the queued prompt. |
| L4 Extended | Relay integration, every supporting production plugin: a slow or unresponsive plugin leaves other sessions, plugins, and the relay responsive; archived sends and queued-prompt cancels are refused without racing archiving; disconnect and reconnect mid-turn resumes without lost or duplicated parts; bridge-owned prompts survive leaving and reopening in order and appear on a second client; a prompt waiting at a dispatch boundary can be cancelled; a permission reply lands while a command or selection-changing prompt waits behind the running turn; a second client observes the same turn and steering prompt. |
| L5 Full | Client end to end, every supporting production plugin: retry status surfaces with attempt and timing; concurrent sends across sessions and plugins interleave without ordering damage; background and resume mid-turn recovers live state; an aborted turn triggers no completion notification. |

## Exploration Guidance

Vary prompt shape, prompt versus slash command, explicit versus default
agent/model, aborting early versus late, sending while busy to steer at a tool
boundary, sending a command or selection change that must wait, cancelling before
dispatch, leaving and reopening while an entry is visible, turn length, and
client count. For Hermes, include text and image prompts,
tool updates, a permission decision, cold history replay, and abort after output
has started.

## Failure Signals

- A slash command holds the client request open for the whole run, or a slow
  plugin blocks unrelated sessions, other plugins, or relay traffic.
- Streaming stalls, duplicates or loses parts, shows an empty user bubble, or
  orders a late envelope at the wrong transcript position; the session never
  returns to idle. A terminal provider failure returns to idle without showing
  its error, the error disappears after refresh or reopen, or a live update
  removes a backend-provided message timestamp. An OpenCode prompt, slash
  command, or bare `/compact` leaves both its local bubble and backend echo in
  the transcript.
- Internal backend command records or synthetic model attribution appear in
  the conversation or replayed history.
- Prompt defaults regress, an approved plan exit does not restore Agent
  across clients and restart, or a defaults-write failure fails the send.
- Reopening or importing a session silently switches its latest transcript
  model to a stale catalog default on the next send.
- A send or cancel succeeds against an archived session, an aborted turn
  triggers a completion notification, or queued sends reorder, vanish, or
  resend. A plain Claude prompt sent to a busy resident process waits for the
  running turn to finish before reaching stdin, carries a priority other than
  `next`, or incorrectly reports idle between an active turn and its queued
  continuation. A bridge-queued prompt disappears after leaving and reopening
  the session, a
  retried send within the dedupe window becomes a duplicate turn, or the
  queued bubble and its dispatched message render simultaneously. Submitted text disappears while
  bridge acceptance or backend startup is still pending, or queued feedback
  uses a visually unrelated or composer-pinned surface, or renders authored
  Markdown as literal syntax.
- A stale-option rejection retains the rejected cache row, waits on an
  unrelated options discovery before answering, remains silent, drops the
  staged prompt, changes FIFO order or prompt identity, refreshes and retries
  without a bound, or leaves a corrected selection on a variant the picker does
  not display.
- An abort, permission reply, or question reply stalls behind a send to a
  busy session on the same session lane.
- Recovery or interruption artifacts from an aborted turn appear in the next
  user turn.
- A normalized user message fails to advance the existing activity marker, or
  assistant/tool/title-only updates replace an established marker and move the
  running session as if they were user activity.
- Scrolled transcript text remains clearly visible through the fade and collides
  with the navigation title or floating composer controls.
- A timestamp peek responds from a reserved system-back edge, detaches or
  vertically scrolls the transcript, captures a mouse selection drag, or moves
  while a fenced code block is handling the horizontal drag.

## Known Limitations

- L3 and above need live backends; an omitted plugin is partial coverage, and
  client end-to-end coverage is phone-only.
- Session-detail refresh behavior is under active investigation, so refresh
  churn is recorded as evidence rather than judged pass or fail.
- The bridge's queued prompts live in plugin memory and do not survive a
  bridge restart (the backend process dies with the bridge). Claude, Pi, and
  the ACP family surface adapter-owned entries; OpenCode and Codex hand prompts
  to their backends immediately and therefore do not.
- A send staged locally (POST not yet accepted) is dropped if the session
  screen is left inside that sub-second window; while disconnected, staged
  sends survive only as long as the session-detail cubit is alive.
- Retry dedupe is bounded to the last 64 dispatched prompt ids per session; a
  retry delayed past that window re-enqueues (accepted residual recorded in
  the plan).
- Pi persists API commands and manually typed slash prompts in the same raw
  shape. Cold replay therefore shows only the slash-command token to avoid
  exposing bridge-owned arguments; live API-command presentation retains only
  the exact user-authored arguments.
- Untested Hermes gap (remove this entry once verified): reasoning streaming
  was never observed from Hermes. An explicit chain-of-thought prompt produced
  no `agent_thought_chunk` against the tested model, so thought-part
  normalization is unverified for this harness.

## Sources

- Bridge: `bridge/app/lib/src/bridge/services/` (prompt, abort, dispatcher,
  event, chat history), `lib/src/bridge/sse/`, and their tests
- Contract: `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart`;
  `shared/sesori_shared/lib/src/models/sesori/send_prompt_error_response.dart`;
  `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart`
- Hermes: `bridge/sesori_plugin_hermes/` and the shared ACP plugin implementation
- Client: `client/module_core/lib/src/cubits/session_detail/`,
  `client/app/lib/features/session_detail/`
- Plans (discovery only): `.plan/completed/relay-request-concurrency`,
  `internal-chat-history`, `.plan/active/session-refresh-reconnects`
