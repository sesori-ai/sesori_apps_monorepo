# Tools And File Changes

## Capability

How a turn's tool activity is normalized and presented: lightweight tool parts
with status and attachments, explicit shell commands with bounded results, and
sub-agent parts, plus the signal that a tool changed files.

## Required Behavior

- Every plugin normalizes backend tool activity into the shared tool part
  contract: stable identity, tool name, lifecycle status (pending, running,
  completed, error, plus a forward-compatible unknown), a bounded title naming
  what the tool touched, and attachments. Shell tools additionally carry the
  explicit command and its bounded output or error. Ordinary non-shell tool
  output snippets and errors stop at the bridge remapping boundary and never
  enter chat history or live client events.
- The title is the tool's primary argument: Claude reads it from the tool input
  (`skill`, `file_path`, `notebook_path`, `pattern`, `path`, `url`, `query`), Pi from the
  tool-call arguments (`pattern`, then `path`), Codex from its argument-derived
  title, and OpenCode and ACP harnesses pass the harness-supplied title through.
  An ACP call without `kind` uses its title as the tool name and drops the
  title, so the card never repeats it.
  Skills that load through a file read of `SKILL.md` are visible by that path.
  Pi learns the title at `toolcall_end`, so a card announced by `toolcall_start`
  shows it from the running or terminal update onward, live and after replay.
  Every step (a tool, a command, a thought, a sub-agent, a compaction)
  renders as one lightweight secondary-text row layout, on phone and desktop
  alike: its icon, or the live sparkle, centred in one 20 px slot, then one
  14 px line holding a bold label and its regular detail, at a button's height
  for the surface's density. A group summary's chevron sits in the same slot.
  Every label starts with a capital, raw tool names included (“Apply_patch”);
  the detail keeps its own case. Ordinary tools show the tool name and title;
  a finished tool says nothing more, and a failed one keeps one signal, its
  red icon. A sub-agent shows its agent, then its task. An explicit `shellCommand` instead renders an underlined
  command disclosure: completed calls say “Ran”; other calls retain their
  pending/running/failed/cancelled/unknown status. Tool-name strings never decide
  whether a shell panel is available.
- Consecutive tool, thinking and sub-agent parts collapse into one summary row
  that counts its finished steps, “N steps”: every thinking block, tool call
  and sub-agent is one step, failed ones included, and a lone finished step
  reads “1 step” like any group. The line names no kinds and counts no
  failures apart. Tapping or
  keyboard-activating the summary opens its finished steps outside the
  transcript, so the transcript's layout never changes: on desktop an anchored
  popover below the summary, 560 px wide and capped at 480 px tall, whose steps
  scroll past the cap and which closes on Esc or an outside click; on the phone
  a sheet titled with the summary. The steps keep their transcript rows, and a
  tool inside still opens its details there. The panel shows the steps finished
  when it opened. Visible text, a file, an agent or a retry part
  ends a group, as does a user or error message; a group may span consecutive
  agent messages and renders in the first one's row, while an automation
  message groups only within itself. A running step stays below the summary as
  its own row and folds into the summary when it finishes; a group of only
  running steps shows no summary. The fold is animated over 200 ms: the live
  row keeps its last look while its height shrinks, it fades and slides up a
  little, and the summary takes it in: a changed count rolls (the old number
  slides up and out, the new one in from below, so “2 steps” rolls only its
  digit), and the summary's width eases so the text after it moves rather than
  jumps. At rest the summary is one line that ellipsizes on a narrow screen. A new group, a new live row, the
  thinking tail's first words and a new agent message row ease their height in
  the same way; user prompts appear at once. Only the rows that change animate,
  and a reader pinned to the newest edge stays pinned while they do. Reduced
  motion makes every such change instant. Finished sub-agents show a neutral icon and
  failed ones a red one, without a status label; the grouping is computed by the
  shared `TranscriptBuilder`, so phone and desktop match.
- The client never classifies a raw tool name or parses tool input.
- A finished context compaction renders as one quiet "Context compacted" row in
  the step style; like visible text it ends a group. While it runs, Pi, Codex
  and DeepSeek show the live row below from the start, and OpenCode v2 once its
  running snapshot loads. When the
  harness exposes the carried-forward summary, tapping the row opens a
  reading-width modal at once. A long summary shows a spinner that the Markdown
  replaces once the modal's entry transition ends (at once under reduced
  motion); a short one shows at once. Without a summary the row is inert. See
  `docs/HARNESS_CAPABILITIES.md` for which harnesses mark compaction.
- The compaction part carries its state: running (with any summary written so
  far), completed (with the summary, freed tokens and an `auto` or `manual`
  trigger when the harness reports them) or failed (with the error when there
  is one). A part from a released bridge carries no state and reads as
  completed with no details; a state status this client does not know reads as
  completed with whichever completed fields it carries, and an unknown trigger
  reads as absent, so the transcript still decodes.
- A running compaction is a live row on phone and desktop: the sparkle, a
  shimmering "Compacting context" and, when its message carries a creation
  time, " · 1m 42s" ticking from that time, so it reads the same after a reopen;
  without one the row shows no time. Screen readers hear the row with the time
  of its last build, not every second. When the harness streams the summary,
  its newest words fade in on one line under the row, as under Thinking. While
  a compaction runs, “Working…” and the sub-agents row give way to it; once it
  settles and the turn goes on, “Working…” returns. The row settles in place,
  keyed by its part: the sparkle cross-fades to the fold icon (or an alert),
  the label stops shimmering and the words fold away, so the row keeps its
  one-line height; reduced motion makes the settle instant. A completed row
  reads "Context compacted · freed 142k tokens · auto" with only the details
  the harness reports, and a manual trigger is never named. A failure stays in
  the transcript as a quiet "Compaction failed" note in secondary text, with
  its error ellipsized on the one line and read whole by screen readers; it
  is inert and has no retry. On OpenCode v2 the words stream from the native
  compaction deltas once the bridge has loaded the running snapshot, at the
  start or, after a bridge reconnect mid-compaction, at the next delta. After
  a reload or reconnect mid-compaction they resume with the next words,
  because OpenCode stores no partial summary. When that snapshot cannot load,
  the deltas are dropped and the row appears when the compaction settles. If
  the bridge's OpenCode stream is down when the compaction ends, the row stays
  running until the next transcript read settles it, like any live part
  stranded by that outage. On Pi, Codex and DeepSeek the time counts from the
  bridge's stamp of the start when the harness sends none, and a Pi attempt
  that Pi retries keeps its first stamp. A Pi compaction that fails or is
  aborted becomes the failure note at the row's place, under its own id so the
  next attempt gets a new row. An unfinished compaction elsewhere (Stop or a
  lost process on Pi, any Codex or DeepSeek compaction without a completion)
  stays running until the turn goes idle, when the bridge's sweep ends it
  with the "turn ended" failure note. DeepSeek's history has no compaction
  record, so its row survives one history re-import and then disappears.
- A running tool or sub-agent is a live row: the turning outline sparkle leads
  it and a primary-text band sweeps across its dimmed label, visible in both
  themes. Reduced motion keeps the sparkle and label still while screen readers
  still hear it. While the session works (a question or permission waiting on
  the user does not count), no step is live and no text streams — before the
  first token and between steps — a “Working…” live row with the same sparkle
  closes the transcript, even when no message has rendered yet (in place of “No
  messages yet”); a starting step or streaming text takes its place and
  the swap eases rather than jumps, as does the row's arrival when work starts
  and its departure when work ends. When the running turn's prompt carries a
  sent time, the row reads “Working… · 1m 43s”, ticking each second from that
  time, so it reads the same after a reopen or on another device; without one
  (see “Live timers” in `docs/HARNESS_CAPABILITIES.md`) it reads plain
  “Working…”. Screen readers hear the time as of the row's build, not every
  second. Transcript durations read “42s”, “1m 02s” or “1h 05m 12s”, seconds
  always shown. While a sub-agent runs and the main agent itself does nothing
  (the bridge reports its turn over, no step of its own runs, no text streams,
  no retry row), a sub-agent row
  takes the same slot, easing in as “Working…” eases out: a spinner like the
  composer's sub-agent pill (never the sparkle or a shimmer), “2 sub-agents
  running in the background · 3m 05s” and a muted second line “You can keep
  chatting meanwhile.” It counts running sub-agents as the pill does (busy or
  retrying) and ticks from the earliest one's start: the message holding its
  sub-agent step, else its own session's creation; with neither it shows no
  time. Both lines always show, so the row keeps its height as the count or
  time changes. It hides while a question or permission waits. Which harnesses
  show it, with a time, is under “Live timers” in
  `docs/HARNESS_CAPABILITIES.md`. A retry row replaces it, with the same
  sparkle and band, and folds away when the retry error clears. Streaming thinking shows a shimmering “Thinking...” with one
  line of its
  latest words below, the older start fading out; a finished thought is one row,
  “Thought” and its first line, that opens the full text. While the reader is
  scrolled away, the jump button reads “Jump to latest”, whatever the session
  is doing.
- Tapping or keyboard-activating a command opens a Shell panel, on the same
  raised inset as other tool output and code blocks, with the
  full available command, output and error in a two-axis scroll viewport that
  fits a short transcript and caps at 144 px. One Copy takes the transcript
  exactly as shown. A sideways swipe anywhere on the panel scrolls the transcript.
  Status stays visible outside the viewport; streamed updates do not close an
  open panel. The panel eases open and shut over 200 ms, growing down from the
  row, and its details stay visible while it closes. In the reversed
  transcript the tapped header stays still while the panel opens and closes
  below it; only when no room is left above the composer (the newest row)
  does the row grow upward. A later resize of an open panel never scrolls
  the transcript, except the eased resize when a fetched output arrives. Screen safe-area insets do not displace its scrollbars.
  Reduced motion opens and closes it at once.
  Tool attachments remain visible when details are collapsed.
  A tool with output or an error but no shell command opens the same panel,
  titled with the tool name, from its row; a tool with neither is a plain row.
  This presentation is shared by phone and desktop.
- Plugin and shared message parts are sealed variants, so text, tool, subtask,
  file, agent, and retry data cannot be combined with unrelated part types. The
  shared variants retain the released `type` values and normalize known payloads
  whose variant-specific fields were omitted by an older bridge into temporary,
  non-null compatibility defaults: empty text/name details, retry attempt zero,
  an unknown file attachment, and pending tool state. Current peers serialize
  those non-null values.
- Shell commands, output and errors are bounded to the shared limit and truncated
  by runes at the common bridge projection, so a character is never split; the
  rule is identical live and on replay. Live events keep the command as the
  released title alias for older clients; transcript pages omit a title that
  equals `shellCommand`, so a reloaded shell row renders its command from
  `shellCommand`. Old title-only payloads still decode. Apps at v1.8.3 and
  older read the command only from the title, so their reloaded shell rows show
  the tool name without the command; the user accepted that on 2026-10-07.
- A transcript page or load-through that asks for `toolOutputDelivery:
  onExpand` carries each completed, error or cancelled tool that has output or
  error as a `summary` tool state: status, title, command and attachments, no
  output or error. Running and pending tools, tools with neither, and subtask
  task states stay full, and live events always carry full parts. A request that
  omits the field (v1.9.0 apps) gets full parts. `POST /session/tool-output`
  answers a summarized part's output and error from the store, or from the
  audit file for an archived session, outside the session queue and without a
  backfill; it answers 404 when the part is missing or is not a tool. Tool
  state JSON without a `form` key (stored rows, v1.9.0 bridges) decodes as
  full.
- The app asks for `onExpand` on every page read and load-through, so a
  finished tool's row opens its panel at once and fetches the output then. A
  v1.9.0 bridge ignores the field and sends full parts, which render as
  before. Until the output arrives the panel shows its title and any command
  over a fixed-height row; a spinner fades in there only after 150 ms, so a
  quick fetch never flashes one, and Copy keeps its place but is hidden. When
  the output arrives the panel eases over 200 ms from that height to its own,
  taller or shorter, the tapped header stays still as when opening, and a
  command scrolled sideways keeps its offset. A failed fetch shows “Could not
  load the output.” with Retry in the same row, so the panel does not change
  height unless large text needs more room, and then eases to it; Retry, or
  closing and reopening, fetches again with a fresh 150 ms spinner delay. The
  header is held still only while the reader is not scrolling: an output that
  lands during a drag or fling never stops it. A tool that finished live
  keeps its output, so a later page that summarizes it still shows it. A fetched output survives a silent
  refresh and reopens at once; a full reload fetches it again on the next
  expand. A full part always wins over it.
- Subtasks retain a prompt bounded to 500 runes, bounded title/outcome/error
  summaries, status, attachments and child-session IDs; ordinary non-shell tool
  stripping never applies to them. The description stays complete because
  clients use it to match a child by title when a harness supplies no child ID.
- Codex code-mode JavaScript is not itself a shell command. Only verified
  `exec_command` input, literal single-invocation code-mode command evidence or
  correlated `commandExecution` data retains shell results. Quoted/commented fake
  invocations and generic shell-like tool names do not classify as commands.
- ACP command authority is adapter-owned, not inferred from execute kind, title,
  or arbitrary content. Antigravity's native alias normalizer and Grok's exact
  terminal-tool metadata feed the same live/replay command merge. Output-only
  and failed deltas preserve commands; reordered initial calls cannot overwrite
  newer evidence. Antigravity exit-only updates retain output and nonzero exit
  annotations do not change the adapter's existing ACP status semantics.
  See `docs/HARNESS_CAPABILITIES.md` for unverified command-source gaps.
- Backend vocabulary stays in the owning plugin. Attachments use client-safe
  sources: local paths never cross, unsafe URLs degrade to metadata.
- A tool that mutates the workspace emits a per-session file-change signal once
  per mutating completion; non-mutating tools, in-progress updates, and repeated
  updates for one completed call emit none.
- Sub-agent, subtask, and agent parts identify their agent and stay attributed
  to the correct session, including work done by a child. Tool state survives a
  reload with the same identity and status; shell commands also retain their
  command and result. Unknown status renders as the fallback. A backend abort
  without a turn identifier still finalizes tools in the active turn.
- Claude `Agent`/`Task` calls render as subtask parts keyed by the tool-use
  id, with the sub-agent description, prompt, and agent type, a lifecycle of
  their own (`pending`/`running` → `completed`, `error`, or `cancelled`), and
  a `childSessionID` naming the sub-agent's child session once known. The task
  notification is the authoritative terminal source; the launching call's own
  tool result is a fallback that a later notification replaces, and a
  background launch never finalizes the part. When Claude resumes the same
  agent after it stopped, the repeated start reopens the existing part as
  `running`, clears its prior outcome, and restores the already-announced child
  to busy. A part appears only once its input names the description and prompt,
  never with placeholder text. On replay the same parts render from the
  transcript, current resident state overrides an earlier terminal notification,
  and a still-running task the session's resident process no longer owns renders
  as `cancelled`.
  Process exit — natural or an explicit stop — cancels every running task.
  OpenCode subtask parts keep a null lifecycle and the child-status fallback.
- Codex replaces a generic `spawn_agent` tool by exact call id with one subtask
  tile linked to the direct child thread. A complete child-owned plaintext
  `NEW_TASK` input owns prompt provenance for the initial child turn; normally
  encrypted input instead retains only the exact nonblank message from the
  matching parent `spawn_agent` call. Parent history, labels, order, timing,
  envelope headers, encrypted content, later resumed input, and metadata-only
  `thread/read` never supply prompt text. Child completion, failure,
  interruption, close, and disconnect settle the tile, with the initial turn's
  first terminal state winning. Parent spawn completion and parent turn
  completion do not settle it. Replay performs the same exact-id replacement
  and takes provenance-safe prompt and terminal facts from the catalogued child
  rollout, never live tracker state.
- DeepSeek projects tool calls and updates through standard ACP with exact call
  identity, terminal state, attachments, and diff content. Its native `web_search`
  and `web_fetch` tools use the same tool lifecycle; they make outbound requests
  when invoked, without starting a Web BFF, HTTP listener, or another process.
  Telemetry remains disabled. Presenter failure degrades to a generic lightweight
  tool card instead of dropping the call. With protocol v2, correlated sub-agent
  starts replace exact `subagent`/`subagent_fork` cards with one child-linked tile;
  identifiable updates arriving before their call are deferred too. Start/end
  events retain the direct parent's transcript and keep root activity busy.
  Launch prompts remain authoritative without child prompt echoes; malformed
  ends finalize known children as error. Startup failures retain one generic
  terminal card. Replay projects typed delegation metadata into the same tile
  identity and terminal policy, or an unlinked tile when no child was created;
  unrelated tools retain the generic ACP projection. Initialization requires v2.
- Cursor's fire-and-forget extensions preserve exact tool-call attribution before
  active-turn fallback. A Task call (`rawInput._toolName: task`) is a sub-agent
  spawn: its generic card is suppressed from the first frame, and the latest
  Task input is kept for the native `subagent_spawned` notification, which
  opens the single tile linked to the child session. The tile's description is
  the spawn's nonblank `task`, else the Task input's description; its prompt
  is the Task input's prompt, else the `task`. The child's model is stamped when
  Cursor announces one. `cursor/task` requests are acknowledged and ignored.
  Replay keeps projecting a completed foreground Task into a childless tile.
  The shapes come from the CLI bundle. Live confirmation on an authenticated
  account is pending: a real spawn/state pair, the child streaming into its own
  session, nested and resumed children, no generic Task card next to the tile,
  and (L3) the tile rendering and opening its child session.
- Antigravity normalizes its `formatted_output`, `exit_code`, `command_line`, and `working_dir` aliases before the
  shared ACP live or replay mapper retains tool state. Raw provider payloads and canonical output are independently
  bounded; local image paths remain metadata and are never read. Exact duplicate text is removed, differing standard
  and provider text is retained within the shared display cap, and a nonzero exit note never changes ACP tool status.
  Native `invoke_subagent` activity remains generic: the official ACP seam supplies no child identity or authoritative
  lifecycle, and its live terminal status conflicts with replay. Sesori does not manufacture a tile, child transcript,
  descendant busy state, or scoped-stop target from prompt-bearing input, call order, or assistant output.
- GitHub Copilot uses the same standard ACP tool lifecycle. Permission linkage
  must be exact while the request is live. Call identity, terminal state, and
  diff content then converge after `session/load`; permission
  decisions are process-local and are not part of replay. Backend tool names
  remain presentation data rather than shared behavior.
- Grok uses that standard ACP lifecycle with exact live permission linkage.
  Root history replaces only metadata-identified `spawn_subagent` tools with one
  deterministic child-linked subtask tile, using the exact child's persisted
  first user-message run as prompt only when that run is nonblank, plus typed
  lifecycle for terminal state/output. A blank or missing first run produces no
  tile; later runs never substitute. Ordinary tools remain generic and ordered
  around the tile, without an empty assistant message after spawn suppression.
  Tool-call identity, pending-to-terminal status, and diff content otherwise
  converge between live events and `session/load`; verified shell commands also
  retain bounded output or error. Grok tool names remain presentation data and
  never become shared domain vocabulary.
  Corrected production-composition QA after PR #1429 verified exact root/child
  replay linkage and child-owned prompt provenance. Owned-phone QA passed one
  completed root tile opening its exact child's transcript read-only, with no
  composer, Stop, permission/question reply, or other mutating controls.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated presentation only: command disclosure/two-axis scrolling, exact command/output copy, six statuses, streaming updates, keyboard activation, eased and reduced-motion disclosure, enlarged text and both themes; attachment visibility and title-only older-peer rendering; every step kind lining up in one row layout with a bold, capitalised label at phone and desktop density; the sparkle leading a live row, and the “Working…” row showing while busy with no live step or streaming text and leaving when a step starts, text streams, the session idles or a retry row shows, ticking “Working… · time” on each whole second from the prompt's sent time or reading plain “Working…” without one, and durations reading “42s”, “1m 02s” and “1h 05m 12s”; the sub-agent row easing in for “Working…” while only sub-agents run, with a spinner, two lines, a time from the earliest start or none when no start is known, a steady height, the screen-reader label read once, and giving way to the main agent's own step, a main agent mid-turn, streaming text, a retry row, idle and a waiting question; a finished live row folding into its group while its count rolls, including one that finishes before it has eased in, a group reading “N steps” with no kind list or failed count and a lone finished step reading “1 step”, a failed step still red in the opened group, a group opening in a desktop popover (Esc and outside-click dismissal, capped height) or a phone sheet without changing the transcript height, instant changes under reduced motion, and a pinned reader staying pinned through the fold. Authoritative tool execution still requires a live turn. |
| L2 Routine | Live plugin, representative: a file-editing tool produces a lightweight tool part with name and terminal status, while a shell tool preserves its command and bounded result. |
| L3 Release | Client end to end (phone), every supporting production plugin: status normalizes consistently, non-shell tool snippets are absent, and shell commands/results/errors render; a mutating tool emits the file-change signal once and a read-only tool emits none; tool cards and subtask/agent parts render. Claude covers a foreground and a background sub-agent tile going running → completed with the result text, tapping the tile opening the child transcript, and a cancelled tile after the process is killed; OpenCode proves a null-lifecycle subtask part still renders and opens as before. On Claude, Codex, OpenCode (background children), DeepSeek and Grok the sub-agent row takes over from “Working…” once the main agent goes quiet, and a prompt sent while it shows is answered before the sub-agents finish; a Claude foreground `Agent` call shows its running tile and no sub-agent row. Copilot covers one read-only tool, one file mutation with permission linkage and diff invalidation, and one failing tool. Grok target coverage: a complete lightweight tool lifecycle, a file diff and invalidation, live permission linkage, and cold-replay identity/status parity. Grok owned-phone coverage passed completed-tile rendering, exact read-only child navigation, and genuine permission Once. File diff/invalidation, mutating-tool permission linkage, failing-tool presentation, and permission denial remain unexecuted. On iOS and macOS, representative plugin with shell commands (for example Claude): a reloaded finished tool, also after a far-prompt load-through and on an archived session, opens at once and loads its output with no jump; against a v1.9.0 bridge the new app renders full parts as before, and a v1.9.0 app against the new bridge receives full parts. |
| L4 Extended | Live plugin, every supporting production plugin: tool parts survive history reload with identity and status intact, shell commands retain their results, and non-shell snippets remain absent; a failing shell command surfaces an error rather than a stuck running state; child-session tool activity is attributed correctly; repeated completion updates do not duplicate the file-change signal. Claude: a reloaded session with a finished background sub-agent shows one completed subtask tile with the same identity and `childSessionID`, a still-running one stays running while its process lives, a resumed terminal agent returns to running in both its tile and child status, and a failed sub-agent renders `error` with the notification summary. |
| L5 Full | Client end to end, every supporting production plugin: rune-boundary truncation is exact for multi-byte shell output; attachments render where emitted and unsafe or malformed sources degrade to metadata; unknown status from a newer peer degrades gracefully. |

## Exploration Guidance

Vary the tool mix per run: read-only inspection, single- and multi-file edits,
shell-style execution, a failing tool, a sub-agent task. Alternate long,
multi-byte, and empty shell output; compare live with a later reload. For Antigravity,
compare command/output aliases, long stdout/stderr, nonzero exits, malformed
native fields, standard images and path-only image metadata live and after
replay. For Copilot, verify permission linkage against the live call, then
cold-replay the resulting call identity, terminal tool state, and diff without
expecting its process-local permission decision to replay. For Grok, compare
read-only, mutating, and failing tools live and after `session/load`, including
one permission-gated mutation, one repeated terminal update, and a verified
shell command with long output. Reload a root with completed/cancelled children
and each child transcript; verify prompt provenance, tile order, and both
lifecycle extension methods. Denial remains unverified and carries no replay
guarantee.

## Failure Signals

- Shell output exceeds the bound, truncates mid-character, or differs between
  live streaming and replay; non-shell snippets reach the client; or a
  completed read/edit/skill card shows only the tool name without its path,
  pattern, or skill, or only the path without the tool name.
- A tool stays running after the backend finished, or an error renders as a
  completion.
- A v1.9.0 app, or a request without `toolOutputDelivery`, receives a summary
  tool part; a summary reaches a live event; or `POST /session/tool-output`
  answers a part that a page summarized with 404.
- Expanding a summarized tool flashes a spinner on a quick fetch, jumps the
  header or the content around it when the output arrives, leaves an empty or
  endless loading panel after a failure, offers Copy without the output, or
  fetches the same output twice at once.
- Shell details grow without bound, pad a short transcript to full height, lose
  long command/output text, copy a truncated preview, let a sideways swipe on
  the panel reveal message timestamps, close during updates, or hide tool
  attachments when collapsed.
- Tool details jump open or shut instead of easing, vanish before a blank area
  collapses, or animate under reduced motion; the tapped header moves while
  there is room below the row, the panel opens behind the composer, or the
  transcript scrolls in a second step after the panel has opened or after a
  later resize of an open panel.
- One step kind's row differs from the others: its icon is sized or placed
  differently, its label starts at another inset, or it stands taller or
  shorter; or a label is not bold or starts lowercase, or the row changes its
  detail's case.
- Steps separated by visible text merge into one group, a group swallows a text
  or file part, a summary counts a running step, a finished step stays outside
  its summary, or a finished tool or sub-agent shows a “Done” label.
- Opening a group grows or moves the transcript, the desktop popover outgrows
  its cap instead of scrolling, ignores Esc or an outside click, or a step
  inside it cannot open its details, a thought its full text, or a sub-agent
  its session.
- A finished step, a new group, a new live row, the thinking tail or the
  “Working…” row appears or vanishes in one frame; the summary's count flickers,
  blanks or jumps instead of rolling, its width snaps, or it stops ellipsizing
  at rest; unrelated rows animate; a reader pinned to the newest edge drifts
  away or sees the jump button while rows fold; or anything animates under
  reduced motion.
- A step that finishes before its live row has eased in raises a framework
  assertion or breaks the transcript instead of folding into the summary.
- A group shows a per-kind list, a failed count, or a lone finished step's own
  row instead of “1 step”, or a summary names a backend tool.
- A finished compaction shows no row, shows its summary inline as a user or
  assistant message, leaves a running `compact` tool beside the row, or opens an
  empty modal; tapping a long summary stalls before the ripple, skips the
  modal's entry transition, or leaves the spinner in place; the Claude summary
  appears live but not after reload, or the reverse.
- A running compaction shows no timer although its message has a creation
  time, its timer restarts on reopen or is announced every second, “Working…”
  or the sub-agents row shows beside it, or “Working…” stays away after it
  settles while the turn goes on; the row jumps, flashes, changes height apart
  from the words folding, or is re-inserted when it settles; a failure shows
  no note, a red alert, a retry or a tappable row; a manual compaction says
  “manual”.
- A live row spins or shimmers under reduced motion, a thinking tail hides the
  newest words or wraps past one line, or the jump button names a step, shimmers
  or changes width instead of reading “Jump to latest”.
- A working session shows no live row between steps, “Working…” stays beside a
  live step or streaming text or after the session goes idle, or a live label's band is invisible
  in either theme.
- “Working…” shows a time that restarts on reopen, runs backwards, or is
  announced every second.
- The sub-agent row shows “Working” or the sparkle, shows while a question or
  permission waits, beside the main agent's own running step or streaming
  text, or while the main agent waits on a foreground sub-agent, jumps instead of easing when it takes over from “Working…”, changes
  height as its count or time changes, or claims chatting on a harness where a
  prompt would wait for the sub-agents.
- Backend naming or payload shape reaches the client unnormalized, or a local
  path or unsafe URL crosses the attachment contract.
- A part carries fields owned by another variant, or a released known-type
  payload fails to decode because an older bridge omitted variant data, or a
  current peer serializes null variant data.
- A Cursor extension cross-binds sessions; a Task call renders a generic card
  next to its sub-agent tile; a spawn opens no tile, a second tile, or a tile
  without a child link; `cursor/task` is not acknowledged or produces a tile;
  a sub-agent state settles the wrong child or an unknown state finishes one;
  or live/replay tagged sub-agent shapes are conflated in replay.
- Antigravity changes ACP status from an exit code, loses an exit note to truncation, leaks an image path as a fetched
  attachment, retains unbounded/redundant raw fields, drops differing text, or produces different normalized state from
  equivalent live/replay source envelopes. Its upstream `invoke_subagent` status mismatch is retained as generic data;
  promoting that call into a child or subtask without a new authoritative seam is also a regression.
- A Copilot tool loses permission correlation while live, or its call identity,
  terminal status, or diff changes when reopened through ACP history.
- A Grok tool loses live permission correlation, changes call identity or status
  after replay, exposes ordinary non-shell output or unbounded shell output,
  loses diff content, emits the wrong number of file-change invalidations,
  leaves a generic spawn beside its tile, binds by description/order instead of
  child id, crosses the first prompt-run boundary, or leaves an empty message
  after spawn suppression.
- The file-change signal is missing after a real mutation, emitted for a
  read-only tool, emitted repeatedly for one call, or wrongly attributed.
- A Claude sub-agent renders as a generic `Agent` tool card, its tile stays
  running after the sub-agent finished or its process died, a background
  launch's "Async agent launched" tool result finalizes the tile, a late tool
  result overwrites a notification-set status, tapping the tile opens the wrong
  or no child transcript, or the tile shows placeholder text before its input
  is complete.
- A Codex spawn remains both a generic tool and subtask tile, pairs by label or
  order instead of exact call id, uses copied parent history as its prompt,
  ignores later native child text, or loses child terminal state after reload.

## Known Limitations

- An interrupted Claude foreground sub-agent renders `cancelled` live (the
  notification reports `stopped`) but `error` on replay, because the transcript
  persists only its error tool result; tool-result text is never matched.
- The Claude CLI 2.1.221 floor was not probed for `task_started` and
  `task_notification` frames; the typed tool-result and notification-text
  substitutes are unit-tested only.

- Available tools, attachments, and sub-agents are backend-specific; a plugin
  that cannot produce a case is not a failure but is also not coverage.
- Rendering needs the client; the phone is the only transcript surface.
- The final DeepSeek phone gate exercised scoped stop and ordered pending input,
  not cold tile/history reload, tool-card parity, or read-only child navigation.
  Those presentation cases remain automated or unexecuted at the client boundary;
  no desktop transcript case was run.
- ACP permission decisions and pending requests are process-local interaction
  state. Cold replay restores the resulting tool lifecycle and diff, not the
  earlier decision or its linkage event.
- Real Antigravity file/shell execution and generated-image output remain unverified; synthetic normalization
  establishes those boundary contracts only. A bounded authenticated 2026-09-12 probe verified native internal
  delegation but found only contradictory generic parent-local ACP tool records, so Antigravity inline subtasks and
  child sessions remain unsupported in Sesori.
- Attachment presentation is being reworked toward referenced images; only the
  shipped build counts.
- An older client decodes the compaction part but ignores its state, summary
  included, and renders nothing, so during a Pi, Codex or DeepSeek compaction
  it shows only “Working…”, without the running `compact` card older bridges
  sent (accepted). While an OpenCode summary streams, an
  older client buffers the words for a part it never shows, so it shows neither
  “Working…” nor a row until the compaction ends and the turn goes on
  (accepted; no old-client code).
- An older client does not tolerate an unknown message-part `type` from a newer
  bridge: history decoding fails and the corresponding SSE event is dropped as
  malformed. Unknown tool status remains forward-compatible.

## Sources

- Live row: `TranscriptActivityBuilder`
  (`client/module_core/lib/src/cubits/session_detail/transcript_activity.dart`);
  `runningChildren` and `isChildRunning`
  (`client/module_core/lib/src/cubits/session_detail/session_detail_resolvers.dart`);
  `TranscriptWorkingRow`, `TranscriptSubAgentsRow`, `TranscriptElapsedTime` and
  `TranscriptDurationFormatter` under
  `client/module_app_ui/lib/src/features/session_detail/widgets/`, with their
  tests
- Contract: `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart`;
  `shared/sesori_shared/lib/src/models/sesori/message_part.dart`
- Bridge: `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`,
  the shared ACP mapper used by `bridge/sesori_plugin_antigravity/`,
  `bridge/sesori_plugin_copilot/` and
  `bridge/sesori_plugin_grok/`, `bridge/app/lib/src/sse/bridge_event_mapper.dart`;
  mappers and tests under
  `bridge/sesori_plugin_*/`; `client/app/lib/features/session_detail/widgets/`
- Tests: `shared/sesori_shared/test/models/message_attachment_test.dart`,
  `bridge/app/test/bridge/sse/bridge_event_mapper_test.dart`
- Claude sub-agents: `bridge/sesori_plugin_claude/lib/src/repositories/trackers/claude_tool_tracker.dart`,
  `claude_event_dispatcher.dart`, `claude_history_mapper.dart`, and
  `bridge/sesori_plugin_claude/test/claude_subtask_lifecycle_test.dart`
- Plans (discovery only): `.plan/completed/output-image-support`,
  `.plan/completed/attachment-references`, `.plan/completed/claude-inline-subtasks`

## Focused automated verification

- `bridge/app/test/bridge/{plugin_to_shared_mapping,acp_tool_projection,codex_tool_projection,backend_tool_projection}_test.dart`
  exercises backend-shaped positive/negative classification, successful and failed
  live/history states, subtask outcomes/IDs, multibyte bounds, released title
  decoding and attachments. ACP cases include partial/reordered updates and
  Antigravity alias/exit-only behavior.
- `bridge/app/test/bridge/repositories/mappers/duplicated_shell_title_mapper_test.dart`
  and the shell-title case in `bridge/app/test/bridge/services/chat_history_archive_test.dart`
  prove that database and archived pages omit only a title equal to `shellCommand`.
- `bridge/app/test/bridge/repositories/mappers/summarized_tool_output_mapper_test.dart`
  summarizes every finished status and keeps every other one,
  `bridge/app/test/bridge/services/chat_history_tool_output_test.dart` covers
  the store and archived pages and output lookups,
  `bridge/app/test/bridge/routing/get_session_tool_output_handler_test.dart`
  covers the route's 404 and 400, and
  `shared/sesori_shared/test/models/tool_state_test.dart` decodes keyless tool
  state as full and a request without the field as inline.
- `client/module_app_ui/test/features/session_detail/widgets/tool_part_widget_test.dart`
  ("a summary part") fetches on opening, holds the spinner back for 150 ms
  (also on a retry), eases to a taller or shorter output with the header and
  title still, keeps the command's sideways scroll, grows and eases the
  failure for large text, lets a fling run on while the output lands, retries
  from the panel and opens a fetched output at once. `client/module_core/test/cubits/session_detail/session_detail_paging_test.dart`
  ("summary tool output") fetches once while a fetch is in flight, retries
  after a failure, keeps the output across a silent refresh and keeps a tool's
  output once it finished live.
- `client/module_app_ui/test/features/session_detail/widgets/transcript_step_row_test.dart`
  measures every step kind's icon, label inset, height and label weight at
  phone and desktop density.
- `shared/sesori_shared/test/models/compaction_state_test.dart` decodes a
  state-less compaction part, an unknown status and an unknown trigger, and
  round-trips every state.
- `client/module_app_ui/test/features/session_detail/widgets/compaction_part_widget_test.dart`
  opens a long compaction summary behind a spinner at both densities and shows
  it at once under reduced motion or when it is short; it also covers the
  running row's timer with a fake clock and its read-once semantics, the
  streamed words, the in-place settle (cross-fade, held height, words folding,
  instant under reduced motion), the details, the failed note and the token
  count formatter. `transcript_step_row_test.dart` measures the running and
  failed rows with the other step kinds, and `session_detail_message_list_test.dart`
  checks the row replaces “Working…” and settles without a re-insert.
- `client/module_core/test/cubits/session_detail/transcript_activity_test.dart`
  covers “Working…” and the sub-agents row giving way to a running compaction,
  and `session_detail_event_buffer_test.dart` streams a running compaction's
  summary across a silent refresh like text and reasoning.
- Owning Claude content/history/tracker, Pi history/dispatcher, OpenCode part
  mapper and v2 compaction mapping, delta and service tests, Codex rollout/tracker/history/event-mapper, ACP replay/content,
  Grok adapter, Antigravity normalizer and DeepSeek replay/time/compaction tests guard backend semantics.
- `bridge/app/tool/benchmarks/tool_projection_payload_size.dart` reproducibly
  reports synthetic serialized UTF-8 bytes before/after projection. It states
  source/starting-HEAD baselines, separates typical already-bounded text from
  oversized stress inputs, and deliberately excludes envelopes, attachment bytes,
  compression, encryption and latency. Already-bounded shell results do not gain
  further output savings from the common bound. Subtask payload growth restores
  intended outcome information; it is not a regression in ordinary-tool trimming.
