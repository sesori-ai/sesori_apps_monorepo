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
- DeepSeek preserves that bridge-facing acceptance contract: the shared ACP
  plugin enqueues and returns while the adapter's `session/prompt` response
  remains pending through owned work, projected output, and durability quiesce.
  The plugin keeps only one prompt in flight per DeepSeek session while allowing
  different sessions to run concurrently. A follow-up accepted during an active
  turn immediately cancels that turn, then dispatches after cancellation and
  durability settlement. Exact advertised slash commands dispatch as commands;
  unknown slash prefixes remain prose.
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
  transition back to idle; retry carries attempt, backend-provided message, and
  timing and returns to busy as soon as the retried request streams output again,
  and finalized messages enter durable history matching a history read. A terminal
  provider failure appears as an inline error message and remains visible after
  refresh or reopen. Backend-provided terminal and retry error text is forwarded
  verbatim for every harness; plugins may flatten an error envelope but synthesize
  text only when the backend supplied none. Backend-provided message timestamps
  remain present through live updates and durable-history reloads, using the
  backend's authoritative source for each path. Internal backend command records
  are not rendered as conversation messages or used as assistant model attribution.
- Claude user prompts appear in the live transcript from the CLI's replayed
  stdin echo under their transcript uuid, so a follow-up prompt stays visible
  and a later transcript backfill converges on the same message instead of
  duplicating it. The bridge worktree context envelope is stripped from the
  echo, and a slash command renders one synthetic user message because its
  echo is the CLI's internal command envelope.
- Codex user prompts use the same visible content live and after rollout replay:
  the bridge worktree context envelope is hidden, authored text remains, and
  bounded inline images render as file parts. An attachment-only initial prompt
  therefore remains visible without exposing the generated context. A plain
  follow-up is sent immediately through `turn/start`; Codex's app server starts
  a turn while idle and steers the active turn while busy, preserving the
  client user-message id in either case. The bridge keeps the authoritative
  active turn until its terminal event even when an older app server returns a
  separate submission id for the steering request.
- A Codex root remains effectively busy after its own turn completes while any
  tracked descendant turn is running. The root's idle status and completion
  signal are deferred and released exactly once after the last child settles;
  the `subAgentActivity started` fact counts as work immediately even when an
  earlier pre-start status said idle. An accepted resumed turn also keeps its
  child and root provisionally busy before `turn/started` arrives.
  Active-session summaries keep `mainAgentRunning` specific to the root, list
  busy child thread ids, and roll a child's pending permission or question up
  to the root's awaiting-input state and pending-input snapshot, including a
  restored request with no live status and a request that arrives while
  `thread/read` is still enriching the spawn. A stop or deletion accepted before
  the child's `turn/started` queues its interrupt until the turn id arrives.
  Closing an active child emits its idle status before any deferred root release.
- A plain Claude prompt sent while its resident process is working is written
  immediately with `priority: next`. Claude absorbs it at the next tool
  boundary when possible, within the active agent turn; otherwise Claude keeps
  it for its own following turn. Several absorbed prompts may share one result,
  while a prompt that starts later settles on that later result. Slash commands
  and model, effort, or permission-mode changes wait for a turn boundary
  instead of changing the active turn.
- A Claude session stays busy while any background task the CLI reported
  (`task_started`) is still running, even after the launching turn's result,
  and returns to idle only after the last task notification and the wake-up
  turn it triggers settle, so one continuous busy span covers launch →
  background work → wake-up and the completion push fires once. The CLI's
  `<task-notification>` delivery records are internal: they finalize the
  matching subtask and are never rendered as user messages, while user text
  that merely discusses the envelope stays visible. Forwarded sub-agent frames
  render in the sub-agent's child session, never as a root turn.
- Stop is scoped for every harness that runs sub-agents (Claude tasks, OpenCode
  child sessions). The client first asks with `confirm`; while sub-agents
  run the bridge refuses with the running count and whether the main agent is
  mid-turn, and the app shows a confirmation: with the main agent idle, "Stop N
  sub-agents"; with the main agent running, "Stop main agent and N sub-agents".
  Dismissing leaves everything running. "Stop main agent only" (`keep`) is
  offered only when the rejection declares `mainAgentOnlySupported`; neither
  current harness can interrupt a running main agent without its sub-agents,
  so both report false and refuse `keep` during a live main turn with the
  running count. With the main agent idle `keep` is honored: the Claude process
  stays resident, the sub-agents continue, their later wake-up turn renders,
  and the completion push is not suppressed. `stop` interrupts and tears
  down, cancelling every sub-agent. With no sub-agents running, stop behaves
  as before with no dialog. An older app stops everything; an older bridge
  ignores the scope.
- Pi keeps at most one lazy resident RPC process per active session and allows
  different sessions to run concurrently. A cold resident starts with the
  turn's requested model and thinking level on Pi's command line so
  `session_start` extensions observe the same selection that the turn will use.
  Startup replays and hydrates message identity before live frames attach or a
  turn dispatches. Same-session prompts
  remain FIFO, and same-selection ordinary follow-ups dispatch with Pi's
  `steer` streaming behavior as soon as the preceding prompt is accepted, so Pi
  injects them at the next tool boundary instead of waiting for the run to
  settle. A model or thinking-level change remains bridge-queued until the
  current run settles. Pi may run model-backed automatic compaction before it
  acknowledges a prompt, so that preflight uses a turn-scale deadline instead
  of the shorter history/control RPC deadline. The prompt remains visibly
  queued alongside a running `Compacting context` tool card while compaction
  runs, including in snapshots loaded by later viewers. The card updates in
  place to `Context compacted` when Pi persists the result; aborting or losing
  the Pi process removes it. An accepted prompt remains bridge-queued
  through startup and selection until Pi echoes its correlated user message,
  including an attachment-only echo; it can be
  cancelled before dispatch, and its undispatched prompt id remains immediately
  retryable while cancellation settles. If a successful run omits an echo, Pi
  maps each stored payload through the same user-message path before clearing
  the queue. Process exit settles dispatched work before queued work reconnects.
  A resident Pi extension may initiate a turn after the bridge queue becomes
  idle. Its visible custom message is attributed as system automation live and
  after replay, while assistant/tool output remains agent-authored. The client
  renders automation on a neutral labelled surface, and it cannot replace
  agent/model prompt defaults or completion-notification text. The complete
  busy-to-idle lifecycle still reaches clients and restarts the resident idle
  window instead of being discarded or reaped mid-turn. An older bridge's
  omitted sender decodes as agent, while an older client ignores the additive
  sender field and retains its prior assistant styling.
- Pi slash commands are accepted by their correlated response or a matching
  extension dialog and remain in the request's sending state until then rather
  than exposing a cancellable bridge-queue entry. The bridge-synthesized
  `compact` command instead publishes its visible command marker before the
  running compaction card, accepts on Pi's `compaction_start`, then keeps the
  resident busy until the native RPC finishes. A rejected native compaction clears
  its running card. Commands reject while that session is busy, and a successful
  ordinary command with no agent run crosses `get_state`
  before returning the lane idle.
  Abort rejects queued work and replaces the process so hidden steering or
  follow-up input cannot leak into the next turn. Its control acknowledgement
  has a short bound: if Pi waits for queued continuation idleness instead of
  answering, the bridge force-replaces the resident rather than holding later
  sends in the session lane for the general history/control timeout.
- Pi accepts only bounded, valid inline GIF, JPEG, PNG, and WebP data. Paths,
  URLs, non-image data, malformed base64, and oversized images fail visibly
  before admission and are never fetched, stringified, or silently omitted.
- Pi discovers models, thinking levels, and extension, prompt-template, prompt,
  and skill commands through bounded approved no-session probes in normalized
  project directories. Because Pi omits built-in TUI commands from `get_commands`,
  the plugin appends one `compact` command and dispatches it through Pi's native
  `compact` RPC with optional user instructions rather than sending `/compact` as
  a prompt. If an upstream command already owns that name, it remains an ordinary
  slash command and the native action is not synthesized. Private instructions
  remain confined to the RPC while the synthetic user marker uses only the
  user-visible command text. Reuse is project-local, refresh always probes, concurrent
  requests for one project coalesce, and a failed refresh never replaces the
  last coherent snapshot. Dialogs raised during probes are cancelled and never
  enter session UI state. Empty Pi sessions remain lazy until their first prompt
  or command. Creation is published before any buffered turn output. Imported
  parent forks preserve exact lineage. Deleting a root fences descendant work
  and dialogs but physically removes only the named root session artifact.
- Hermes runs turns through ACP v1 over `hermes acp`: initialization uses the
  first non-terminal provider authentication method, image prompt parts remain
  available, streamed updates use the shared ACP normalization, and abort uses
  session cancellation. A follow-up accepted during an active turn uses that
  same cancellation path, then dispatches after the interrupted turn settles.
  Available models come from Hermes's ACP session model state, and the selected
  exact model ID is applied through Hermes's `session/set_model` extension before
  each changed-model turn. A rejected model fails before prompting. Completed
  assistant text is finalized at each tool boundary, so earlier prose in a
  multi-tool turn does not depend on the final turn snapshot. Sesori does not
  call form-elicitation or unadvertised session-close methods to complete an
  ordinary turn.
- GitHub Copilot runs through the same standard ACP normalization for text,
  reasoning when emitted, tools, statuses, commands, cancellation, and image
  parts. Its complete model/mode/reasoning selection is validated before
  prompt acceptance and applied before dispatch. Different Copilot sessions can
  run independently; prompts within one session remain serialized.
- Grok uses standard ACP normalization for text, reasoning, tools, statuses,
  commands, cancellation, and permission-mediated work. Initial prompts are
  text-only because its initialize result does not advertise image capability.
  The exact model/reasoning tuple is validated and applied before dispatch;
  stale or rejected selection fails visibly without prompting. Different Grok
  sessions run independently while one session remains serialized. Its ACP
  sub-agent extension renders a child subtask and status and keeps the root and
  plugin busy after the root turn settles. The child terminal event is published
  before any derived root idle. A finish with `will_wake: true` atomically swaps
  the child for an autonomous-root hold and releases that hold only on the
  matching `turn_completed` prompt `subagent-completed-<child id>`. A new user
  prompt cancels that autonomous turn and waits for the hold to clear before its
  ACP prompt frame is dispatched. Spawn and non-final finish changes invalidate
  the project summary. Deletion refuses a running child or root with active
  child work until that work is stopped or finishes; global interruption,
  process exit, and disposal cancel or clear child activity and holds without
  leaving the root busy or delivering tracker changes to a closed event stream.
- Existing-session ACP prompts remain bridge-queued while an earlier same-session
  turn, declared process-wide lane, resume, or selection blocks their
  `session/prompt` frame. ACP v1 has no standard steering operation, so Sesori
  never sends overlapping prompt requests. It does define `session/cancel`:
  the shared ACP plugin therefore defaults every harness to active-turn
  stop-and-send, immediately cancelling the active turn and
  dispatching the queued input after cancellation settles. Further already-queued
  inputs retain FIFO order. A concrete plugin may disable that fallback only when
  it supplies another immediate active-turn delivery path; natural-completion
  queueing is not valid production behavior. Cursor, Hermes, DeepSeek, Copilot,
  Grok, and OMP use the shared fallback. Their
  synthetic user transcript message is published only after its frame flushes
  successfully to the agent's stdin. A prompt rejected after that dispatch
  renders a durable inline error, preserving the agent's diagnostic detail
  rather than transitioning silently to idle. The shared 30-minute ACP prompt
  safety bound measures same-session inactivity, not total turn duration:
  matching inbound notifications or server requests restart it, while activity
  from another concurrently running session does not. Follow-up and replayed user
  messages preserve ordered text and bounded data-backed image parts, including
  attachment-only prompts. Initial projection contains only normalized
  user-visible text plus those images; injected context, local paths, and URLs
  remain absent. OMP runs different sessions concurrently because its permission
  and form requests carry explicit session IDs.
- DeepSeek maps text, reasoning, tools, plans, title/config updates, compaction
  completion, and bounded warning errors through standard ACP plus its narrow
  status extension. Retry and compaction-start notifications are validated but
  intentionally emit no shared event because DeepSeek does not supply the timing
  required by the shared retry state and the active turn is already busy.
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
- Opening an existing session that required a first or externally stale history
  replay adopts and persists the latest assistant/error transcript selection,
  including an OpenCode effort variant. Other opens select valid persisted
  prompt defaults first and otherwise continue with the latest assistant/error
  transcript model before falling back to agent or catalog defaults. The
  transcript model remains authoritative when a retained provider cache does
  not list it, so a terminal-imported session cannot silently resume on a
  different provider.
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
  returns the typed `staleSessionOptions` rejection. OpenCode keeps the requested
  selection on its synchronous message reservation; when that endpoint collapses
  a rejection into a generic 500, the plugin checks fresh project options and
  classifies the failure as stale only when the requested selection is absent or unavailable.
  The client force-refreshes the options, replaces only unsupported queued
  selections without changing FIFO order or prompt ids, warns the user, and
  retries once. A failed refresh or second stale rejection leaves the prompt
  visible and queued instead of disappearing or entering a retry loop.
- Each plugin stamps that prompt id onto the user-message echo of its own
  dispatch, using the link its backend exposes — Claude's queue entry, ACP's
  accepted send, Pi's dispatcher, Codex's client-supplied identifier, and
  OpenCode's server-reserved ordered message identifier that the bridge reuses
  for the real dispatch. Claude compares image echoes by their semantic source
  fields, including an image echo that omits the usual replay marker, so
  backend-added metadata cannot strand the queued row. OpenCode applies the same
  correlation to prompts, slash commands, and manual compaction.
  Compaction renders only the user-entered command arguments; bridge-authored
  guidance remains backend-only. A message authored in the backend's own UI
  carries no prompt id and renders as an ordinary transcript message. A harness
  that publishes no user echo at all leaves the client's own copy to be settled
  by the next snapshot instead.
- Queued and sending text render as the newest rows inside the scrollable
  transcript, never as controls pinned above the composer. They use the same
  brand bubble and Markdown rendering as settled user text; a compact status
  rail and subtle queued outline carry the transient state, with the outline
  change animated when reduced motion is not requested. A turn started on one
  client is visible to every other client of that bridge.
- User and assistant message text containing a raw HTML block renders that
  markup as a literal code block, so a pasted page or error body stays visible
  and copyable instead of being swallowed by the Markdown renderer.
- Selecting across user, assistant, or reasoning text copies the rendered
  content with readable structure: each transition between vertically stacked
  Markdown blocks contributes exactly one line break regardless of their visual
  spacing, while same-line fragments such as a list bullet and its text retain a
  separating space. Partial selections spanning blocks preserve the same
  boundary instead of joining paragraphs or adding empty lines. Desktop keeps
  those native selection/context-menu surfaces. In its inline composer, Enter
  sends and Shift+Enter inserts a newline, except that an active IME composing
  range retains Enter for candidate confirmation; mobile retains plain Enter as
  newline and Cmd/Ctrl+Enter as the hardware-keyboard send shortcut.
- Live message envelopes render in transcript timestamp order even when events
  arrive out of order; late envelopes append after existing envelopes with the
  same timestamp rather than reordering an established turn. Finalized parts
  that arrive before their envelope are retained and reconciled without showing
  an empty user bubble or switching the composer to follow-up wording.
- Desktop Escape first releases an active text editor; otherwise it dismisses
  only the current popup route. It never turns Escape into ordinary page Back,
  and a closer surface-specific handler such as the image viewer wins.
- Transcript content scrolling behind the top navigation or floating composer
  dissolves into a strong surface-colour fade, keeping the title and controls
  visually separate and screenshot-readable without text collisions.
- When the software keyboard opens, interactive content resizes above it while
  the page surface remains painted underneath it. Rounded or translucent iOS
  keyboards never reveal a black route or platform background around their edges.
- Transcript rows render in a plain reversed list with newest content at the
  bottom. Following stays pinned through appends and streaming growth; scrolling
  away freezes live row content until reattachment. Sending, queued, retry,
  streaming, working, and settled rows keep stable identities and transitions.
- A leftward touch, stylus, or trackpad drag across the transcript reveals all
  message timestamps together without changing vertical scroll or follow state,
  then settles closed on release. System-back edges remain reserved on iOS and
  Android gesture navigation, mouse drags remain available for text selection,
  and a horizontal drag inside a fenced code block scrolls only that block.
- Mobile and desktop compose the same transcript and composer presentation for
  messages, queued prompts, tool and subtask output, errors, pending
  interactions, links, image viewing, child-session navigation, text input,
  commands, agent/model selection, abort, and declared image attachments. Each
  shell owns routing, external-link policy, image and keyboard adapters, banners,
  voice capability, and bottom-control composition. Mobile supplies real voice
  capture. Desktop declares voice unsupported and always presents an effective
  text-first composer even when the saved cross-surface preference is
  voice-first; it omits the voice entry rather than exposing a dead control,
  while eligible root sessions retain the shared diff action.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated shared presentation and desktop shell coverage: representative selectable transcript content renders through the shared session-detail view, the desktop session route is present, and desktop renders the text-first composer and declared attachment/diff actions without resolving voice capture. Live plugin, representative: a prompt streams assistant output and returns the session to idle. |
| L2 Routine | Live plugin, representative: slash command returns on acceptance; prompt defaults update; first and stale transcript replay reconciles prompt defaults before the opening snapshot is applied; abort stops a turn and reports its outcome; finalized messages are immediately readable from history; a recognized stale option returns the typed rejection only after cache invalidation. Automated ACP coverage proves same-session activity extends the prompt inactivity deadline while concurrent-session activity does not. Automated Pi coverage keeps visible custom messages system-attributed across live and replay without changing agent defaults or completion text. Automated Codex coverage holds root idle through a running child, releases it once, rolls child pending input into the root summary, and reconciles an already-idle child abort. Shared/desktop widget coverage proves Enter versus Shift+Enter policy, active-IME candidate confirmation, unchanged mobile modifier-send behavior, safe Escape popup dismissal, and selectable transcript content. |
| L3 Release | Client end to end on phone and desktop, every supporting production plugin: text, reasoning, tool, and status events stream with consistent normalization and the shared output bound; agent, model, and variant apply per send; streaming and queued feedback, text composer, sending, and abort controls render on both surfaces; voice capture remains mobile-only; and a stale selection refreshes, warns, and retries once without losing the queued prompt. Claude: a stop while a background sub-agent runs shows the scope dialog, cancelling it leaves the tile running and its wake-up turn later arrives, confirming cancels it, and a stop with no sub-agents shows no dialog; the session stays busy until the last sub-agent's wake-up turn settles. OpenCode: a stop while a delegated child session runs shows the scope dialog, cancelling it leaves the child running, confirming aborts the root and the child, and a stop with no running child shows no dialog. DeepSeek, Copilot, and Grok cover busy stop-and-send. Copilot additionally covers an exact advertised slash command and reasoning only when its selected model emits it. Grok covers exact model/effort application, accepted-send timing, abort, visible failure, and idle completion without claiming image input. A Pi custom message renders as labelled automation rather than agent output. |
| L4 Extended | Relay integration, every supporting production plugin: a slow or unresponsive plugin leaves other sessions, plugins, and the relay responsive; archived sends and queued-prompt cancels are refused without racing archiving; disconnect and reconnect mid-turn resumes without lost or duplicated parts; bridge-owned prompts survive leaving and reopening in order and appear on a second client; a prompt waiting at a dispatch boundary can be cancelled; a permission reply lands while a command or selection-changing prompt waits behind the running turn; a second client observes the same turn and steering prompt. Two Copilot sessions and two Grok sessions run concurrently while each preserves its own ordering and selection. |
| L5 Full | Client end to end, every supporting production plugin: retry status surfaces with attempt and timing; concurrent sends across sessions and plugins interleave without ordering damage; background and resume mid-turn recovers live state; an aborted turn triggers no completion notification. |

## Exploration Guidance

Vary prompt shape, prompt versus slash command, explicit versus default
agent/model, aborting early versus late, sending while busy to steer at a tool
boundary where supported or stop-and-send over ACP, sending a command or
selection change that must wait, cancelling before dispatch, leaving and
reopening while an entry is visible, turn length, and client count. For Hermes,
include text and image prompts, tool updates, a permission decision, cold history
replay, and abort after output has started. For DeepSeek, include busy
stop-and-send around tool use or pending input. For Copilot, include prose, an
advertised command, tool use, a selected-option change, a queued follow-up
cancellation, abort, and two independent sessions. For Grok, include text,
reasoning and tool updates, default and changed model/effort, stale selection,
provider failure, early and late abort, busy stop-and-send, and two sessions.

## Failure Signals

- A slash command holds the client request open for the whole run, or a slow
  plugin blocks unrelated sessions, other plugins, or relay traffic.
- An accepted ACP prompt rejection returns the session to idle without a durable
  inline error containing the backend's diagnostic detail. An active ACP turn
  times out after 30 total minutes despite continuing same-session updates, or
  unrelated concurrent-session traffic keeps a silent turn alive.
- Streaming stalls, duplicates or loses parts, shows an empty user bubble,
  orders a fast assistant envelope before its accepted user message, exposes a
  permission before that user or its preceding tool card, or orders a late
  envelope at the wrong transcript position; the session never
  returns to idle. A terminal provider failure returns to idle without showing
  its error, a harness replaces backend-provided terminal or retry error text,
  a plugin status serializes with a private discriminator and is dropped at the
  shared SSE boundary, the error disappears after refresh or reopen, or a live update
  removes a backend-provided message timestamp. An OpenCode prompt, slash
  command, or bare `/compact` leaves both its local bubble and backend echo in
  the transcript.
- Internal backend command records or synthetic model attribution appear in
  the conversation or replayed history. A visible Pi custom message renders as
  agent output, loses its automation attribution between live and replay,
  changes agent/model defaults, or becomes completion-notification text.
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
  Markdown as literal syntax. Message text that embeds a raw HTML block loses
  everything from the first block-level tag onward.
- A stale-option rejection retains the rejected cache row, waits on an
  unrelated options discovery before answering, remains silent, drops the
  staged prompt, changes FIFO order or prompt identity, refreshes and retries
  without a bound, or leaves a corrected selection on a variant the picker does
  not display.
- Copied chat text runs headings, paragraphs, list bullets, table cells, or
  separate message parts together, or inserts empty lines based on their visual
  spacing instead of one structural line break. Desktop Enter inserts a newline,
  Shift+Enter sends, active IME candidate confirmation submits the draft, Escape
  pops an ordinary cockpit page or bypasses a closer surface handler, or
  transcript context-menu selection disappears.
- A cold Pi process exposes a stale default model or thinking level to startup
  extensions instead of the pending turn's selection, or a cold follow-up wakes
  the process but times out in pre-prompt automatic compaction before reaching
  the agent; an initial or later viewer exposes only
  the queued prompt while compaction is underway; the running card is replaced
  instead of updated when compaction ends, or survives an abort or process
  exit.
- An abort, permission reply, or question reply stalls behind a send to a
  busy session on the same session lane, or a stop-and-send ACP follow-up waits
  for the active turn to finish naturally instead of cancelling it before dispatch.
  A Pi abort waits for the general history/control timeout, lets hidden steering
  resume after Stop, or leaves later sends stuck in their sending state.
- Recovery or interruption artifacts from an aborted turn appear in the next
  user turn.
- A Claude session reports idle while a background sub-agent still runs, or
  shows a transient idle between the task notification and its wake-up turn; a
  `<task-notification>` envelope renders as a user bubble, or a prompt that
  quotes the envelope disappears; sub-agent text appears in the root transcript.
- A Codex root reports idle while a child is starting or still runs, never
  releases its deferred idle after the child settles, emits completion more
  than once, omits a busy child id, omits an awaiting-input root after reconnect,
  reports awaiting input without returning the child's actionable request from
  the root snapshot, accepts a pre-start child stop or deletion without
  interrupting the arriving turn, re-announces deleted child activity, or leaves
  a closed child's visible status busy.
- A plain stop kills running Claude sub-agents or OpenCode child sessions
  without asking, the scope dialog appears when none run, a confirmed stop leaves a sub-agent running or the
  session stuck busy, a killed sub-agent leaves the session busy or the stop
  request hanging, or dismissing the dialog stops anything.
- A Grok turn dispatches before exact model/effort selection settles, accepts a
  stale tuple, overlaps same-session prompts, serializes unrelated sessions, or
  loses text, reasoning, tool, status, or terminal failure output. A child lets
  its root report idle while still running, finishes after the derived root idle,
  fails to invalidate the project summary, drops root busy state between a waking
  child's finish and its autonomous completion, dispatches a user prompt before
  that completion, releases a hold for an unrelated prompt, disappears locally
  when deletion cannot stop it, survives global interruption/process exit, or
  leaves tracker events subscribed after plugin disposal.
- A normalized user message fails to advance the existing activity marker, or
  assistant/tool/title-only updates replace an established marker and move the
  running session as if they were user activity.
- Scrolled transcript text remains clearly visible through the fade and collides
  with the navigation title or floating composer controls.
- A live append or streaming update moves a detached viewport, an outgoing
  prompt blanks or duplicates during its sending-to-sent transition, keyboard
  and composer insets obscure newest content, or the keyboard reveals a black
  background around its rounded or translucent edges.
- A timestamp peek responds from a reserved system-back edge, detaches or
  vertically scrolls the transcript, captures a mouse selection drag, or moves
  while a fenced code block is handling the horizontal drag.

## Known Limitations

- Flutter's selection and clipboard APIs expose selected content as plain text
  only, so chat copy preserves document structure but not Markdown styling or
  metadata such as bold, italics, and hyperlink destinations
  (`flutter/flutter#104206`).
- L3 and above need live backends; an omitted plugin is partial coverage.
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
- Grok does not advertise ACP image prompt capability in the supported release;
  image attachments are not Grok turn coverage.
- Copilot reasoning is model/account dependent; absence is not a failure unless
  the selected advertised configuration is known to emit reasoning. Standard
  ACP plan updates currently produce only an internal todo invalidation that the
  session client ignores and cold replay does not collect, so plan presentation
  is not supported Copilot release coverage.
- A Claude task that never reports a notification keeps the session busy and
  its process resident until a stop, delete, or exit; `background_tasks_changed`
  is not used to reconcile because it precedes the frames it would race.
- Claude Code's only stop primitive (`interrupt`, observed on 2.1.257) stops
  background sub-agents along with a running main turn, so a main-agent-only
  stop exists only while the main agent is idle; interrupting a live main turn
  always stops its sub-agents.
- OpenCode aborts a foreground task child together with its root (the task
  tool cancels it), while background children outlive a root abort; `stop`
  therefore aborts each running child explicitly, and the tracker cannot tell
  the two kinds apart, so main-agent-only is not offered while the root runs.
- Untested Hermes gap (remove this entry once verified): reasoning streaming
  was never observed from Hermes. An explicit chain-of-thought prompt produced
  no `agent_thought_chunk` against the tested model, so thought-part
  normalization is unverified for this harness.

## Sources

- Bridge: `bridge/app/lib/src/services/` (prompt, abort, dispatcher, event,
  chat history), `bridge/app/lib/src/sse/`, and their tests
- Contract: `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart`;
  `shared/sesori_shared/lib/src/models/sesori/send_prompt_error_response.dart`;
  `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart`;
  `shared/sesori_shared/lib/src/models/sesori/abort_session_request.dart`
- Claude: `bridge/sesori_plugin_claude/lib/src/services/claude_session_service.dart`
  (running tasks, scoped abort) and `test/claude_session_service_test.dart`;
  `client/app/lib/features/session_detail/widgets/session_abort_scope_dialog.dart`
- Hermes: `bridge/sesori_plugin_hermes/` and the shared ACP plugin implementation
- DeepSeek: `bridge/sesori_plugin_deepseek/` and the shared ACP plugin implementation
- Copilot: `bridge/sesori_plugin_copilot/` and the shared ACP plugin implementation
- Grok: `bridge/sesori_plugin_grok/` and the shared ACP plugin implementation
- Client: `client/module_core/lib/src/cubits/session_detail/`,
  `client/module_app_ui/lib/src/features/session_detail/`,
  `client/app/lib/features/session_detail/`, and
  `client/desktop/lib/features/sessions/desktop_session_detail_screen.dart`
- Plans (discovery only): `.plan/completed/relay-request-concurrency`,
  `internal-chat-history`, `.plan/active/session-refresh-reconnects`
