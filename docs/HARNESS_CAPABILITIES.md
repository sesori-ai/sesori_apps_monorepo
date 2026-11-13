# Harness Capability Matrix

Sesori strives for feature parity across harnesses. This matrix records the
capabilities of the Sesori integration that not every harness has, so a gap is
a deliberate, visible state rather than an accident. Update it whenever a
capability lands for some harnesses but not others, or a harness limitation is
verified or lifted.

Capability tables include registered plugins where the relevant integration behavior has been verified. Antigravity is
included below, including the bounded authenticated sub-agent assessment completed on 2026-09-12. Its sub-agent cells
describe what Sesori can expose through the official ACP seam, not whether the native runtime delegates internally.

## Legend

| Mark | Meaning |
|---|---|
| ✅ | Implemented: Sesori exposes the capability for this harness. |
| ⬜ | Not implemented: the harness and the seam Sesori drives can provide it, Sesori does not yet. |
| 🚫 | Not supported: the harness or the protocol seam Sesori drives cannot provide it. The footnote names the verified version. |

## Automation transcript attribution

| Harness | Native evidence | Sesori availability |
|---|---|---|
| Pi | Visible `custom` messages / `custom_message` entries | ✅ Automation attribution live and after history load. |
| Claude Code | User-role frames, transcript records and `queued_command` attachments with `origin.kind: peer` | ✅ Automation attribution live and after history load, including `isMeta` peer records and peers queued mid-turn. |
| Claude Code (task notifications) | User-role `<task-notification>` turns with `origin.kind: task-notification`, `queued_command` attachments in `task-notification` mode, or a whole envelope on CLIs without origin | ✅ A notification no known Agent/Bash task absorbs renders as an Automation step live and after history load, including one queued mid-turn. |
| OpenCode (task notifications) | Unknown | Unverified: needs a probe of whether a background child's completion is injected as a user turn. |
| Codex (task notifications) | None | Not applicable: no background-task completion arrives as a user turn. |

Claude attribution uses host provenance, not plugin names or text matching. It
covers any sender using that peer/socket path, but `origin.from: unknown` does
not identify which plugin sent it. Missing/unmodelled origins and channels that
may forward human input are not promoted to automation. Existing task-outcome,
tool-result, compaction and hidden-metadata behavior remains separate.

Claude task notifications fold into the launching Agent/Bash tile when the
tracker knows the envelope's tool-use id. Otherwise (a SendMessage-resumed
agent, an unknown id or no tool-use id) the turn becomes one completed
Automation step labelled by the envelope's summary, with its result as output
and the summary as error on failure; note, usage and output-file are dropped.
An envelope that does not parse still renders as Automation text, never as a
user bubble. Only a text block that is a whole envelope counts as one without
provenance, so a prompt quoting the protocol stays user input.

Verified on **2026-09-25** with native Claude Code **2.1.281**, an isolated MCP
socket sender and a loopback model fixture: idle wake-up, live stdout provenance
and persisted records. Native captured frames/history also pass through the
production Claude parsers/mappers. Shared client fixture tests cover the existing
Automation surface; authenticated-provider and full client/relay journeys were
not exercised for this change.

A command Claude queues while a turn runs (a follow-up, a peer message or a
task outcome) is persisted as a `queued_command` attachment instead of a user
record. History maps it like its live replay frame: the attachment's
`source_uuid` (the record's own `uuid` on CLIs that omit it) as the id, the same
sender and parts, at the point the model received it. Verified on
**2026-09-26** with native Claude Code **2.1.281** captures and live rows the
bridge stored from CLIs 2.1.237 to 2.1.281.

## Harness-generated user frames

Some harnesses talk to the model through the `user` role themselves. Codex
writes a picked skill's body to its rollout this way (see the table). Claude Code
does it most: loading a skill injects the whole `SKILL.md` body plus
its `<ARGUMENTS>` blob as a separate `user` frame, and the CLI uses the same
shape for image captions, "your response was cut off" nudges, sub-agent plumbing
and automation preambles. Sesori drops those frames so the transcript shows only
the compact `Skill / <name>` step row (see "Ordinary tool titles").

The CLI flags them `isSynthetic` on the `stream-json` socket and `isMeta` in its
transcript records; both mean "the CLI wrote this", are normalized at the parse
boundary, and are decided by one predicate the live dispatcher and the history
mapper share. Sesori's own peer injections carry the same flag, so
`origin.kind: peer` keeps them visible as Automation (see "Automation transcript
attribution"). Frames already stored by an earlier bridge keep their bubble; the
residue is cosmetic and is not migrated.

| Harness | Native evidence | Sesori availability |
|---|---|---|
| Claude Code | `user` frames/records flagged `isSynthetic` (stream) or `isMeta` (transcript), including the injected skill body | ✅ Dropped live and on replay; peer injections, tool results, task-notification outcomes and the post-compaction summary still render. |
| OpenCode | Skills exposed as `PluginCommandSource.skill` commands, no injected body record (OpenCode 2 attaches the skill to the prompt and keeps its body out of the user message) | Not applicable: no harness-authored user turn to hide. |
| Codex | A picked skill's `SKILL.md` body is written to the rollout as a user `response_item` wrapped in `<skill>…</skill>`, after the `$name` prompt; it is never sent live | ✅ Hidden on replay by its `<skill>` envelope, like `<environment_context>`. Verified live on 2026-11-12 with Codex 0.167.2. |
| Pi | Skills exposed as `PluginCommandSource.skill` commands. `/skill:name args` is stored as one user message holding a `<skill>` block followed by the arguments, and a prompt template as its expanded text (verified live on 2026-11-12 with Pi 1.5.2) | The expanded message is the user's own turn, shown as `/name args` (see "Command and skill bubbles"). |
| Grok, Antigravity, Copilot, Cursor, OMP, Hermes, DeepSeek | None | Not applicable: the ACP seam has no skill concept and no harness-authored user turn. |

## Command and skill bubbles

A command or skill run from the command picker should leave the user's bubble
showing what they typed, `/name args`, live and after history load, while the
harness receives its own invocation.

| Harness | Native evidence | Sesori availability |
|---|---|---|
| OpenCode 2 skill | The prompt's user message keeps only the typed text and lists the skill under `skills` without a `mention` | ✅ `/skill args`, live and after history load. Verified live on 2026-11-12 with OpenCode 2.2.6. |
| OpenCode 2 native command | `POST /api/session/{id}/command` takes no id or metadata, and the stored user message holds only the expanded template | ⬜ Not supported: the bubble shows the expanded template, live and after history load, because nothing in the message names the command. Verified live on 2026-11-12 with OpenCode 2.2.6 and 2.2.7. |
| Codex skill | Invoked as `$name args` text plus a structured `skill` input (name and `SKILL.md` path); the live `userMessage` item and the rollout's `UserMessage` item keep that `skill` entry. The text input is unchanged and the model still gets one injected `<skill>` record | ✅ `/name args`, live and after history load, rewritten only when the item names the skill. When the catalog no longer lists the skill for the session's directory, or the `skills/list` lookup fails, the turn is sent as text only and keeps `$name args`. Verified live on 2026-11-12 with Codex 0.167.2. |
| Pi | `/name args` reaches Pi's `prompt` RPC, which stores only the expanded text as the user message: a prompt template's body with the arguments substituted, or a `<skill name=… location=…>` block followed by the arguments | ✅ `/name args` live for both: Sesori pairs Pi's expanded user message with the pending command. ✅ `/skill:name args` after history load, decoded from the `<skill>` block. After history load a prompt template still shows the expanded template, because nothing in the stored message names it. Native shapes verified live on 2026-11-12 with Pi 1.5.2. |
| Claude Code | Commands and skills both run as `/name args` | ✅ `/name args`, live and after a bridge restart. Verified live on 2026-11-12 with Claude Code 2.1.323. |
| DeepSeek, Hermes | Built-in commands only; no user commands or skills over ACP | ✅ `/name args`, live and after a bridge restart. A built-in that runs its arguments as a turn (DeepSeek `/plan <text>`, Hermes `/queue <text>`) adds that turn as its own turn. A newer app shows only the run's card for it, live and after a reload, as the bridge folds that turn into the card (see "Command and skill run names"); an older app shows it as a bubble. Verified live on 2026-11-12 with the DeepSeek adapter 0.2.2 and Hermes 0.21.5. |
| Grok, Cursor, Copilot, Antigravity | Not checked | Unverified: on 2026-11-12 Grok needed `grok login`, the Cursor CLI was older than the supported minimum, and the Copilot and Antigravity runtimes were not installed on the test machine. |

## Command and skill run names

A newer app shows a command, skill or MCP prompt run as an event card named on
the user turn (`MessageUser.invocation`), from "Sending…" through reopening
the session and restarting the bridge. The bridge names the commands it sent
when the harness echoes the send's prompt id, and keeps the name in its history
store across reloads. A plugin may also name a run from the harness's own
record. A harness that doesn't declare `namesCommandInvocations` keeps the
`/name args` bubble on every app.

| Harness | Native evidence | Sesori availability |
|---|---|---|
| OpenCode 2 native command | `POST /api/session/{id}/command` takes no id and answers 204; the command's callback admits its user message to the session inbox (`session.inbox.enqueued`) before the request returns. History keeps only the expanded template | ✅ Named live: the plugin gives the first inbox message without a Sesori prompt id, admitted while the command request is outstanding, the command's prompt id. A message typed in the TUI in that same moment would take the name instead. A command whose echo never arrives, such as one lost in an event-stream gap or one that timed out and never ran, leaves its expectation open, so the session's next message without a Sesori prompt id takes its name. After a reload or bridge restart the name comes from the bridge's history store, by the stable message id. Verified live on 2026-11-12 with OpenCode 2.2.7. |
| OpenCode 2 skill | The user message lists the skill under `skills` without a `mention` | ✅ Named live and from OpenCode's own history: a message with exactly one unmentioned skill names it, with the message text as its arguments. Verified live on 2026-11-12 with OpenCode 2.2.7. |
| OpenCode 1 | Commands and compaction take the message id Sesori names | ✅ Named live from the prompt id; after a reload the name comes from the bridge's history store, as OpenCode 1 message ids are stable. History doesn't name the command. Not verified live: no OpenCode 1 runtime on the test machine. |
| Codex skill | The live `userMessage` item echoes the prompt id as `clientId` and lists the picked skill as a `skill` input; the rollout's `UserMessage` item keeps both | ✅ Named live and from the rollout: a message whose text starts with `$name` of a listed `skill` input names it, with the rest of the text as its arguments. A skill picked in the Codex CLI is named too. Verified live on 2026-11-12 with Codex 0.167.2, including after a bridge restart with an empty history store. |
| Codex `/compact` | Compaction adds no user turn, only a `ContextCompaction` item | Nothing to name: no user turn. Codex has no other commands. |
| Claude Code | Every command and skill runs as `/name args`. The CLI echoes it, and records it, as a `<command-name>/name</command-name>` + `<command-args>args</command-args>` envelope under the uuid of the stdin frame that sent it. The catalog lists every command as a command, and is read in the plugin's own directory, so it misses project-level `.claude/commands` and skills | ✅ Named live: the plugin shows the run at dispatch under the stdin uuid, with its prompt id, so the bridge stamps it. History names the envelope as the same row, with the kind from the catalog, else unknown ("Custom"), and above the compaction it ran into, which Claude records first. A command run in the Claude CLI, including local ones such as `/model`, is named after a reload too. Verified live on 2026-11-13 with Claude Code 2.1.323: live, reload, bridge restart and a command queued mid-turn. |
| ACP family (Cursor, Copilot, Grok, Antigravity) | The live echo carries the prompt id. A harness that replays the turn as the `/name args` text Sesori sent records the run that way | ✅ Named live from the prompt id, and from the replay: the shared ACP layer names a replayed user turn whose only text is `/name args` for an advertised command, with the kind from the catalog, else unknown ("Custom"). Not verified live: Cursor and Grok need real accounts that can't use the test proxy, and the Copilot and Antigravity runtimes aren't installed on the test machine. |
| Hermes `/queue` | Hermes records neither the `/queue` line nor its "Queued for the next turn" reply; the replay shows the queued text as its own user turn | ✅ Named live from the prompt id. After a reload or bridge restart the bridge's store folds that replayed argument turn into the card, so the card is the only row for it. The live-only "Queued" reply and the drained turn's live answer stay as extra rows after a re-import. Verified live on 2026-11-12 with Hermes 0.21.5. |
| DeepSeek `/plan` | The adapter records no command line; the replay shows the command's "Plan mode on" reply, then the text as its own user turn | ✅ Named live from the prompt id; after a reload or bridge restart the argument turn folds into the card, as for Hermes. After a reload the card sits below the "Plan mode on" reply, the replay's order, instead of above it. Verified live on 2026-11-12 with the DeepSeek adapter 0.2.2. |
| Oh My Pi | The live echo carries the prompt id. Its history replays a command as the expanded prompt, not as `/name args` | ✅ Named live from the prompt id. The replay can't name the run, so after a reload or bridge restart the name survives only where the bridge's store matches the replayed row by id or content. Step 10 of the invocation-view series owns naming it from OMP's own record. |
| Pi prompt template | Pi expands `/name args` before echoing the user turn, and stores only the expanded body | ✅ Named live: the plugin gives the expanded echo the oldest pending command's prompt id. After a reload or bridge restart the name comes from the bridge's history store: the plugin maps each Pi message to the same id live and on replay (`pi:<session>:user:<timestamp>:<ordinal>`, from Pi's message timestamp and order, not its entry id), so the stored row keeps its stamp. A template run outside Sesori isn't named, as Pi's record doesn't name it. Verified live on 2026-11-12 with Pi 1.5.2. |
| Pi skill | Pi stores `/skill:name args` as a `<skill name=… location=…>` envelope followed by the arguments | ✅ Named live from the prompt id, and from Pi's own history: an envelope names `skill:name`, with the text after it as the arguments. Verified live on 2026-11-12 with Pi 1.5.2. |

## Bridge worktree note

A dedicated-worktree session's first prompt or command arguments open with a
note the bridge writes for the agent. The bridge strips it from every text part
it receives, live and from history, when the note opens the text, optionally
after one command token such as `/review`.

| Harness | Sesori availability |
|---|---|
| Claude Code, Codex, Pi, ACP family | ✅ Hidden from prompts and commands, live and after history load. |
| OpenCode | ✅ Hidden from prompts. ⬜ Still visible after a native command whose template puts `$ARGUMENTS` after other text: the server expands the note into the middle of the message. Checked in code on 2026-10-26. |

## Sesori agent instructions

Claude Code and Codex sessions get `sesoriAgentInstructions` from
`sesori_bridge_foundation` through the harness's own system-prompt or
developer-instructions input, never through a prompt or the user's instruction
files; the other harnesses do not get it yet. Today it says how the app
resolves relative file paths.

| Harness | Sesori availability |
|---|---|
| Claude Code | ✅ `--append-system-prompt` on every launch. The CLI records a conversation's system prompt on its first request and keeps it until compaction, so a session created before this keeps its old prompt until then. Verified live on 2.1.318, 2026-11-07. |
| Codex | ✅ `developerInstructions` on `thread/start` and `thread/resume`, after the user's own `developer_instructions` from `config/read`, which the field would otherwise replace. Codex records them as developer messages, which the transcript drops. A resume reads the config from the thread's rollout directory. A failing `config/read` fails the start or resume. Verified live on 0.166.0, 2026-11-07; both fields exist since 0.139.0. |
| Pi, OMP | ⬜ `--append-system-prompt`, but a CLI value replaces the user's discovered `APPEND_SYSTEM.md`, so it must be passed along. Checked on Pi 1.5.0 and OMP 18.16.0, 2026-11-07. |
| Grok | ⬜ `session/new` `_meta.rules`, which needs an ACP activation hook. Checked on 1.0.30, 2026-11-07. |
| DeepSeek | ⬜ Needs the Sesori adapter to register a system-prompt section. |
| OpenCode | ⬜ v1 `system` on each prompt; v2 only an experimental instruction-entry route. Checked on 2.2.5, 2026-11-07. |
| GitHub Copilot | ⬜ `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`, unverified whether it adds to the user's instructions. Checked on 1.0.80, 2026-11-07. |
| Cursor, Hermes, Antigravity | 🚫 No system-prompt input on the ACP seam Sesori drives. Checked on Cursor 2026.07.23 and Hermes 0.21.5, 2026-11-07; Antigravity in plugin code only. |

## Transcript turn boundaries

The client groups a transcript into turns from its messages alone, so a
follow-up sent while a turn runs stays inside that turn only where the harness
delivers it into the running turn. The bridge's prompt index
(`POST /session/prompts`) kinds every stored prompt with the same shared rule
(`splitPromptTurns` in `sesori_shared`) over normalized history, so every
harness gets the index. The client applies the same rule to the range it has
loaded, so a prompt at the start of a partial range can lack the earlier
context the full-history index sees. See `docs/regression/transcript-turn-navigation.md`.

| Harness | Follow-up sent while a turn runs | Stays in the running turn |
|---|---|---|
| Claude Code | Taken at the next tool boundary; history replays it where the model received it | ✅ |
| Codex | `turn/start` steers the active turn | ✅ |
| Pi | Sent with the `steer` streaming behavior | ✅ |
| OpenCode | Sent at once into the running turn | ✅ |
| Oh My Pi | Steered through OMP's `_session/steering` extension when the process advertises `_meta.steering.supported` (18.12.6 does, as does the 18.19.0 source) | ✅ The running turn takes it at its next tool-batch or model-call boundary. Slash commands, a follow-up that changes the model, effort or agent, one queued behind another waiting prompt, or a failed steering request use stop-and-send instead. Input OMP does not admit (the turn was ending or stopping) is sent as the next turn without a cancel. |
| ACP family: Antigravity, Copilot, Cursor, DeepSeek, Grok, Hermes | Stop-and-send: the bridge cancels the turn, then sends | 🚫 Opens a new turn: ACP v1 has no steering operation, and none of these plugins implements the shared steering hook (checked in code on 2026-11-05). |

## Quota-reset auto continuation

Claude/Pi also implement named-session readiness for idle, retry, queued work
and pending input, including known persisted sessions without a resident process.
Other harnesses return unavailable readiness. The bridge implements durable,
session-level opt-in through `PATCH /session/auto-continuation`, scheduled sending,
and the authoritative setting/outcome in session responses and updates. Phone
and desktop chat share opt-in, a persistent menu toggle and outcome notices.

Audit date: **2026-09-24**. Internal terminal quota reporting is implemented for
the Claude Code and Pi cases below. Scheduled continuation is implemented through
the headless API for those reporting formats; live post-reset provider recovery
remains unverified. The
[plan](../.plan/completed/quota-auto-continuation/PLAN.md) was retired on
2026-11-02 with live-provider recovery and macOS desktop QA accepted as unexecuted.
The [evidence record](../.plan/completed/quota-auto-continuation/EVIDENCE.md)
distinguishes observed local errors from upstream contracts and open checks.

Eligibility depends on a terminal quota interruption **and** a usable reset
time for the selected provider/account/model. Native transient retries are a
different capability. “Not implemented; unverified” means the control is
unavailable and protocol support has not yet been established. It is not a claim that
the harness cannot support this feature; do not mark it 🚫 without verification.

| Harness | Reset evidence | Sesori availability |
|---|---|---|
| Claude Code | Tagged session- or weekly-limit error with IANA zone | ✅ Conditional; root terminal error only. |
| Pi | Recognized `openai-codex` error text | ✅ Conditional; final RPC settlement verified on 0.85.1 / 0.84.1. |
| Codex | Local and documented reset timestamps | Not implemented; failed-turn bucket binding unverified. |
| OpenCode | Raw error data reaches mapper | Not implemented; reset payload/provider attribution unverified. |
| GitHub Copilot | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Cursor | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Hermes Agent | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Oh My Pi | ACP seam differs from Pi RPC | Not implemented; reset reporting unverified. |
| DeepSeek | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Grok Build | ACP payload needs inspection | Not implemented; reset reporting unverified. |
| Antigravity | Official ACP payload needs inspection | Not implemented; reset reporting unverified. |

- Claude recognizes tagged `rate_limit` assistant errors beginning “You've
  hit your session limit” or “You've hit your weekly limit”. The observed time/zone format yields a UTC reset
  only when it identifies one future time on the original local date. Unrecognized
  dates, past times, unknown zones, and ambiguous/nonexistent DST times remain
  unknown. Root errors report only after an unsuccessful, non-aborted result;
  forwarded subagent traffic cannot arm or replace the root candidate.
  Process-wide SDK rate-limit frames remain ignored because their rejected
  window has no verified message attribution.
- Pi's local `openai-codex` assistant errors sometimes report a relative retry
  duration; others give no reset. Other providers/formats remain unverified.
  A positive duration is anchored to the original assistant timestamp. Unknown
  or malformed resets remain unknown. Synthetic-provider RPC probes on the
  then-current managed target (0.85.1) and PATH floor (0.84.1) confirmed that
  `agent_settled` follows final retry resolution; they have not been re-run on
  the current target (1.5.2) or floor (0.99.0). Those probes did not exhaust a real account;
  provider-format evidence comes from local errors and pinned upstream source.
  This evidence does not establish support for Oh My Pi's ACP seam.
- Codex local rollouts and documented app-server account limits contain reset
  timestamps; terminal usage-limit errors are already rendered. Bind the failed
  turn to its applicable exhausted buckets; an account snapshot cannot schedule.
- OpenCode raw backend errors reach the mapper before presentation flattening.
  Generic 429 responses and native retries do not establish quota exhaustion.
- Generic ACP has no universal reset field. Inspect each adapter's actual error
  data/extensions; provider behavior can differ. Billing/credit exhaustion with
  no reset is unschedulable. Native application UI or displayed text alone does
  not establish a usable timestamp through Sesori's driven protocol.

Existing error messages remain visible, including errors with unknown resets.
Other descriptors report quota support as unavailable until their provider and
terminal-turn binding are verified. There is no shared model-name allowlist.
Enabling an unavailable harness returns 501; disabling an existing preference
remains available. Known resets use a two-minute buffer and one ordinary
`Continue.` attempt. Non-idle readiness pauses checks for five minutes; unknown
resets never schedule. Manual send, Stop, archive and newer native activity cancel
the current wait while retaining the preference for later quota interruptions.

## Individual queued-prompt cancellation

| Harness / boundary | Status |
|---|---|
| Pi and Claude, still bridge-pending | ✅ Implemented before dispatch; successful cancellation prevents backend submission. |
| Pi and Claude, already dispatched and awaiting user echo | 🚫 Individual cancellation is not supported through the driven seam; retained rows show Sending without trash. Immediate steering remains enabled. |
| ACP adapters, including OMP, before prompt-frame writing | ✅ Implemented; a cancelled pending entry never writes its prompt. Once writing starts, cancellation is refused and the row reports Sending until the user-message projection arrives. An OMP follow-up being steered reports Sending the same way; one OMP does not admit returns to Queued and can be cancelled again. |
| OpenCode and Codex | No retained queue entries through this API; this does not claim a native per-item cancellation capability. |

Pi's installed 0.85.1 RPC `clear_queue` clears **all** steering/follow-up work,
including extension-owned input, and carries no Sesori prompt IDs. It cannot
safely implement deletion of one row; Sesori does not clear/replay that native
queue. This limit is verified from installed 0.85.1 native source and has not
been re-checked on the current target (1.5.2) or floor (0.99.0). Dispatch-state and
cancellation evidence is synthetic plugin/bridge/core/widget coverage, not a new
live authenticated run. Older public bridge payloads without dispatch ownership
remain explicitly unknown and retain best-effort cancellation. Only a reported
dispatched state suppresses trash. A late cancellation refusal is not success:
the client reports it without hiding still-live input; existing queue events and
reconnect snapshots keep the displayed state authoritative.

## Explicit shell-command presentation

Ordinary tools retain name, bounded title, status and attachments; only
adapter-verified shell commands retain command/output/error. Subtask outcome/error
summaries are separate and remain available. All retained tool text is
rune-bounded at live/history wire projection. Live events keep the released
title alias for older clients; transcript pages omit a shell tool's title when
it equals its `shellCommand`. A page request that asks for `onExpand` tool
output gets each finished tool that has output or error as a summary, and the
bridge serves that detail through `POST /session/tool-output`, which the app
fetches when the tool's row is expanded. The bridge applies
this after the plugin boundary, so it covers every harness below that retains
output; it adds no gap beyond the command sources listed here.

| Harness | Status and established command source |
|---|---|
| Claude | Implemented: exact `Bash` input command, retained through tool-result correlation and transcript replay. |
| OpenCode | Implemented: exact `bash` tool input command (v2's `shell` tool, which aliases `bash`, included) in generated SSE/REST tool parts. |
| Codex | Implemented: `commandExecution.command`, `exec_command` arguments, literal single-invocation code-mode commands, and correlated command-execution evidence. Normalized `shell` names and arbitrary JavaScript/title text are not authority. |
| Pi | Implemented: `bash` tool-call arguments and typed `bashExecution.command`, live and replay. |
| Grok | Implemented: exact `_meta["x.ai/tool"].name == "run_terminal_command"` plus typed `rawInput.command`. Evidence is the owning repository fixture, not a fresh upstream capture. |
| Antigravity | Implemented: canonical native command normalized from `CommandLine`, `command_line`, `commandLine`, `command`, or native output command aliases. Evidence is owning generated DTOs corroborated against pinned `AntigravityProtocol.ts` and synthetic fixtures; no new upstream/runtime verification. |
| Cursor, OMP, Hermes, DeepSeek, Copilot | Not implemented / command source not yet verified. Existing execute permission/kind or launch-command fixtures do not establish session shell-command provenance. This does **not** mean not supported by the harness. |

Generic ACP does not infer commands from titles, execute kinds, arbitrary content,
or command-shaped inputs. Adapter command evidence merges through the same live
and replay hook; status/output-only updates retain the last verified command.
Codex code-mode extraction accepts JSON argument objects or a literal first `cmd`
property in one real `tools.exec_command` invocation (single/double quotes and
whitespace accepted). Expressions, multiple commands and other JavaScript forms
need trustworthy correlated command-execution evidence; raw scripts never become
commands. No general JavaScript parser or runtime execution is involved.

## Ordinary tool titles

Non-shell tool cards show a bounded title naming what the tool touched (file
path, search pattern, skill, URL) instead of only the tool name; output and
errors stay stripped. Skills load through a file read of their `SKILL.md` on
harnesses without a dedicated skill tool, so the read path is the skill signal.

| Harness | Status and title source |
|---|---|
| Claude | ✅ Tool input `skill`, `file_path`, `notebook_path`, `pattern`, `path`, `url`, or `query`, first present; live tracker and transcript replay. |
| Pi | ✅ Tool-call arguments `pattern`, then `path`; live from `toolcall_end`/`message_end` and replay. `toolcall_start` carries no arguments, so the title first appears with the running or terminal update. |
| OpenCode | ✅ Native tool part `title`. |
| Codex | ✅ Argument-derived title (`cmd`, `command`, `path`, `filePath`, `query`, else bounded raw arguments). |
| Grok, Antigravity, Copilot, Cursor, OMP, Hermes, DeepSeek | ✅ Agent-supplied ACP `tool_call` title, when the agent sends one; Sesori does not derive titles from ACP inputs. A call without `kind` uses its title as the tool name and drops the title, so the card does not say it twice. OMP's own tool name, sent as a top-level `name` outside the ACP schema (from `18.18.8`), names its cards before `kind`, so task, wait and ask no longer read "Other"; the other ACP harnesses keep `kind`. |

## Live timers

"Working…" ticks the time since the running turn's latest user message was
sent: a message sent mid-turn, else the prompt that opened the turn, from that
message's `time.created`. Each mid-turn message restarts it; automation does
not. A prompt the bridge held before delivery counts from the bridge's
acceptance instead, on a screen that saw it held. Without either time it reads
plain "Working…"; the client never starts its own clock.

| Harness | Prompt sent time |
|---|---|
| OpenCode, Codex, Pi, DeepSeek | ✅ Live and after reload. |
| Claude | ✅ Live from the `--replay-user-messages` echo's `timestamp` (verified 2026-09-26 on CLI 2.1.281), and after reload from the transcript record. A slash command's synthetic bubble is stamped at dispatch. A message sent mid-turn is stamped when the CLI picks it up at its next tool step, so the restart waits for that step. |
| Grok, Antigravity, Copilot, Cursor, Hermes, OMP | ✅ For prompts Sesori sent: ACP carries no message time, so the bridge stamps the instant it dispatched the prompt (or created the session for a first prompt). A prompt read back from the harness's own history (`session/load`) stays undated, so a turn it opens shows plain "Working…". |

The Prompts screen shows each prompt's time and groups the prompts under day
headers from the same prompt time. Where it is missing the row leaves its time
empty and sits in a "No date" group; a session with no timed prompt shows no
times and no day headers.

| Harness | Prompts screen times |
|---|---|
| OpenCode, Codex, Pi, DeepSeek, Claude | ✅ Live and after reload. |
| Grok, Antigravity, Copilot, Cursor, Hermes, OMP | ✅ For prompts Sesori sent, from the bridge's dispatch stamp. A prompt read back from the harness's own history has no time and sits in "No date". |

Prompt numbers on the Prompts screen come from the bridge's own message
history, so every harness numbers its prompts. An older bridge sends no count,
and the rows show no numbers.

While only sub-agents run (the bridge reports the main agent's turn over, and
it streams nothing and runs no step of its own), the transcript shows "N sub-agents running in the background · time"
and "You can keep chatting meanwhile." The time counts from the earliest
running sub-agent's start. On every harness that is when the bridge saw it go
busy after seeing it not busy (live or in a status read), so a resumed sub-agent
counts from its resume. Otherwise (an older bridge, or a sub-agent first seen
already busy, as after a bridge restart) it falls back to the `time.created` of
the message holding its sub-agent step, else the child session's own
`time.created`, as the table lists. With
none, the row shows no timer. The second line claims that a prompt sent now reaches the
main agent at once; no harness where the row shows queues it behind the
sub-agents. A main agent blocked on a foreground sub-agent is still mid-turn
(`mainAgentRunning`), so the row stays hidden and the running sub-agent step
shows instead: a prompt sent then waits for the sub-agent to return. Claude
and the ACP harnesses republish the activity summary when the main turn ends
with sub-agents still running; a bridge released before this does not, so the
flag stays set there and "Working…" shows in place of the row until the
sub-agents finish.

| Harness | Fallback start (no bridge busy time) | Prompt while sub-agents run |
|---|---|---|
| Claude | ✅ The sub-agent step's message time. | ✅ For background `Agent` calls (`run_in_background`): the turn ends at launch, and a prompt is written to the CLI at once and starts a turn. A foreground `Agent` call keeps the turn running, so the row does not show; verified live 2026-09-26 on the Claude CLI (stream-json): a prompt sent 8 s into a foreground call was taken up only when the call returned 11 s later. |
| Codex | ✅ The sub-agent step's message time. | ✅ `turn/start` at once. Verified live 2026-09-26 on codex-cli 0.156.1 (app-server): the parent's turn ended with its sub-agent still running `sleep 90`, and a new prompt started a parent turn answered in 2 s. |
| OpenCode | ✅ The child session's `time.created`. | ✅ For background children the parent is idle and `prompt_async` starts a turn. A foreground Task is the parent's own running step, so the row does not show. |
| DeepSeek | ✅ The sub-agent step's message time. | ✅ By code, not probed live (the adapter is not installed on the probe machine): the parent idles while a background child runs, and the shared ACP path sends `session/prompt` at once. A foreground child keeps the parent's turn running, so the row does not show. A prompt that meets DeepSeek's own follow-up turn after a child settles is unconfirmed. |
| Grok | ✅ The child session's `time.created`: a saved child's `created_at`, else its `updated_at`, else the instant the bridge first stored the child. | ✅ `session/prompt` at once while the root is idle. A prompt sent during the wake turn that follows a finished sub-agent cancels that turn and is then answered. |
| Cursor | Not applicable: the root turn stays open while any sub-agent runs, so the row never shows. | Not applicable: a follow-up prompt is stop-and-send, and the root cancel stops every sub-agent, background ones included. |
| Antigravity, Copilot, Hermes, OMP, Pi | Not applicable: no running sub-agent lifecycle reaches the client, so the row never shows. | Not applicable. |

## OpenCode v2 adapter

Startup selects the v2 adapter for 2.0.11 or newer; the generated surface and managed downloads target 2.2.7.
V1 PATH behavior is unchanged (minimum 1.14.0). Managed v1 upgrades migrate the native database one-way.

| Capability | Status |
|---|---|
| Explicit parent-linked creation | Not implemented. The native create API accepts `parentID` since 2.0.23, but no Sesori flow creates parent-linked sessions and the 2.0.11 floor lacks it, so the request is refused before mutation. Native forks remain standalone roots, never children of their source. |
| Conditional/external form rendering | Not implemented; native-only. Visible replies preserve native keys/types and numeric bounds; native validation remains authoritative. |
| Native archival | Not implemented: OpenCode `2.1.0`+ archives natively (`PATCH /api/session/{id}` with `archived`), but the `2.0.11` minimum cannot; archival stays in the bridge database. |
| Prompt/compaction correlation | Implemented with caller-supplied native IDs and stateless projection. |
| Skills | Implemented. `GET /api/skill` (2.0.11+) lists built-in, project and user skills; Sesori lists each as a `PluginCommandSource.skill` command named by its id, after the native commands, and hides a skill whose id matches a native command name or `compact`, since those names run the command. Running one sends a prompt with the arguments as text and the skill as a `skills` attachment, the same way OpenCode's own clients invoke it; the server adds the skill's instructions to that turn. The user message shows only the arguments, so a skill run with no arguments leaves no user bubble. Verified live on 2.2.7. |
| Custom-command correlation | Not supported by the native command route: no caller ID or result ID is exposed. Command dispatch still waits for native acceptance. |
| Option catalog change events | Implemented for `agent.updated`, `command.updated`, `provider.updated` and `model.updated` (empty payloads in 2.2.7): each rereads the options of every project the bridge already holds a catalog for, so the next picker open shows the change. 2.2.7 sends them when a cold location finishes loading and after it notices an edited `opencode.json`, agent or command file; credential changes announce `provider.updated` per its source, which was not probed live. The bridge opens a project and new sessions by the project's real path, because 2.2.7 watches only that path and misses file edits in a location opened through a symlink (for example macOS `/tmp`); the project keeps the path the user opened, and a path that no longer exists is sent unchanged. A session or loaded location keeps the directory OpenCode reports, so a session created through the symlink earlier still reads that location's options until OpenCode reloads it. `skill.updated` refreshes the same way, so an added or edited skill shows up too (verified live on 2.2.7 by adding a project skill). |
| Shared background server | Implemented. When OpenCode's own `opencode serve --service` is registered, healthy and 2.0.11 or newer, the bridge uses it instead of spawning a private server. When none is running in managed mode without an explicit `--opencode-bin`, the bridge runs `opencode service start` with the selected runtime and uses that service, which keeps running after the bridge stops, as one started by the TUI does. The phone, TUI and desktop then share one server's turns, events, permissions, forms and Stop. When the service stops or moves, the plugin fails after a 5-second debounce and the next request re-attaches, starting the service again if needed. Turn it off with `--opencode-no-shared-service`, an explicit `--opencode-bin`, or OpenCode's `opencode service set disabled true`. When the selected runtime is older than the 2.0.11 floor (including OpenCode 1), or the start fails or times out, the bridge spawns its own server, and a service started later on the same database can resume that server's in-flight turns a second time. OpenCode-specific: no other harness has a shared server, and OpenCode 1 has no service. |

## Managed runtime

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sesori-managed runtime installed on request | 🚫 | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |
| Superseded managed runtime upgraded automatically on bridge start | 🚫 | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |

Antigravity can explicitly download Google's proprietary official runtime pair directly from `dl.google.com`. Before
choosing Install, review [Google's terms](https://antigravity.google/terms) and
[Antigravity documentation](https://antigravity.google/docs/). Sesori independently pins and verifies six
archives: macOS x64/arm64, Linux x64/arm64, and Windows x64/arm64. macOS x64 support is **implemented** for
package `1.4.5`, including managed installation and explicit/PATH pair selection. Every archive keeps the server
and local harness as siblings, uses a conservative two-minute bound for each archive listing/extraction command,
and must pass the isolated initialize-only
identity check before placement. A configured `--antigravity-bin` remains authoritative and removes Install.
A 2026-11-12 macOS arm64 run of package `1.4.5` passed the production managed installation (including its
initialize-only validation) and a network-denied `--version`; other native targets and authenticated behavior have
not been run on `1.4.5`.
Linux requires Info-ZIP `unzip` with ZipInfo support, checked before download.
The [Antigravity operator guide](ANTIGRAVITY.md) covers the exact pair, manual setup, remote personal login and
retained-history behavior. Implemented marks here do not claim completed authenticated end-to-end verification.

Claude, Hermes, and Grok have no Sesori-managed runtime at all: they resolve a
user-installed CLI from PATH or an explicit binary option, so the managed
install and startup-upgrade rows do not apply. Separately, standard descriptors
can identify an outdated default PATH runtime; updating it stays with the user
for every harness, because the bridge never runs a harness updater.

The managed startup upgrade only replaces a runtime Sesori already manages. A machine with no
managed version directory keeps the explicit Install action; it never downloads
a runtime the user has not asked for.

### Harness settings contract limitations (verified 2026-09-07)

These gaps apply to every registered harness through the current management wire seam
(`shared/sesori_shared/lib/src/models/sesori/plugin_management.dart` and install-progress SSE).
They do not claim that a harness's native CLI could never implement an equivalent feature.

| Capability through the current management seam | Status |
|---|---|
| Client-controlled automatic-update preference | 🚫 Not supported: no preference or command; existing bridge-start managed upgrades are unchanged. |
| Pause/stop/cancel a managed installation | 🚫 Not supported: no command or stopped outcome; these UI controls remain hidden. |
| Distinct update-required setup status | ✅ `runtimeOutdated` with optional sanitized version; no update action yet. |
| Enabled preference when runtime is unknown | 🚫 Not supported: unknown does not prove disabled; clients omit the switch. |
| Overall installation percentage or active-session count | 🚫 Not supported: only optional download percentage and idle/busy/unknown work state are reported. |
| Replay a failed installation observed by this client within the connection | ✅ Implemented for every harness advertising installation; memory only, not cross-device history. |

## Reopening a session whose model is gone

Only OMP and Codex are assessed here. Other harnesses are not assessed.

| Harness | Status |
|---|---|
| OMP | 🚫 Not supported from `18.6.3` (probed live on `18.6.3`; unchanged in the `18.12.6` and `18.19.0` sources, not probed live there): OMP's ACP `session/load` and `session/resume` refuse a stored session whose saved model can no longer be used ("Could not restore model"), by upstream design. A prompt on such a session fails with an inline error that names the model. Opening its history while the bridge store is stale serves the history the bridge already stores, with a persistent banner saying the session can't be continued. A session the bridge holds no record of still fails to open. Its persisted cleanup is retried at bridge startup. Upstream: https://github.com/can1357/oh-my-pi/issues/14806. |
| Codex | 🚫 Not supported when the thread's model provider is no longer the configured one, by upstream design (probed live on codex-cli `0.167.1` with an isolated `CODEX_HOME`, 2026-11-12): `thread/resume` answers JSON-RPC `-32600` with `data` `{"type": "modelProviderMismatch", "modelProvider": <thread's>, "currentModelProvider": <configured>}`; per the schema, `modelProviderNotConfigured` carries only the thread's provider and `modelProviderPolicyConflict` adds `requiredModelProvider`. The send fails with a 409: a mismatch names both providers and how to switch back, not-configured names the thread's provider and says to add it back to the config, and a policy conflict names both providers and says the session can't be continued. The app shows that message as a second line under "Couldn't send", with Retry and Remove. |

## Failure reasons shown to the user

A refused send shows a second line under "Couldn't send", and a harness that failed to start shows one under "Failed"
in the harness list, as a row on its detail page, in the new-session harness picker and in the desktop tray popover,
only when the plugin wrote a sentence for the user (`PluginRefusalException`, `PluginStartException.userFacing`).
Every other failure keeps the generic wording; raw backend errors are never shown as these reasons. Harnesses not
listed have no plugin-written reason for either failure today (⬜). "Managed process" covers the shared server start
used by Codex and OpenCode: the configured port in use, no port it could start on, not ready in time, and the
harness exiting while starting.

| Harness | Refused send | Failed start |
|---|---|---|
| Codex | ✅ Model provider mismatch, not configured, or policy conflict | ✅ No runnable `codex` binary; managed process |
| OpenCode | ⬜ | ✅ `--opencode-no-password` with OpenCode 2; version below the v2 minimum; managed process |
| GitHub Copilot | ⬜ | ✅ No supported Copilot CLI |
| Antigravity | ⬜ | ✅ Runtime missing, rejected, unsupported, unreadable, or failing its startup check |

## External session activity

Every pull-to-refresh imports from each routable harness. The import moves an
existing session's time forward to the time the harness reports, so work done
in the harness's own terminal or desktop app reorders the list after the next
pull. The bridge keeps its monotonic timestamp merge and local title overrides.
Apart from a manual refresh, the only import is the automatic hydration import
each harness runs when it becomes ready, until its completion marker for the
current catalog version is recorded; after that, outside activity reaches the
list at the next pull. Opening a session also catches outside turns in that one
session without an import (see "Opening a session").

| Harness | Status |
|---|---|
| Claude Code | ✅ The newest timestamped record in the transcript's last 64 KiB, re-read on every scan; the modification time only when that window has none. The transcript's modification time alone is not activity: the CLI appends untimestamped metadata such as `cost-state` when its process exits (observed in real CLI `2.1.319` transcripts on 2026-11-09) (#2462). |
| Codex | ✅ Newest of rollout modification time, session-index activity and creation time, so terminal and desktop work counts even when the session index is stale or absent. Verified live on `0.167.0` (2026-11-09): a `codex exec resume` turn moved its session to the top after one pull. |
| OpenCode | ✅ The session's `time_updated`, from the read-only database snapshot or the running server. |
| Pi | ✅ Session file modification time, re-read on every scan. |
| OMP | ✅ ACP `session/list` `updatedAt`. Verified live on `18.18.5` (2026-11-09): Sesori's long-running ACP process reports a turn made by a separate `omp -c -p` process, and one pull moved the session to the top. |
| Grok | ✅ Root sessions: ACP `session/list` `updatedAt`, verified live on `1.0.30` (2026-11-09) against a long-running ACP process after a separate `grok -c -p` turn. Sub-agent sessions use `summary.json` `updated_at`, not verified live. |
| Hermes | ✅ Sessions created through ACP, whose `updatedAt` Hermes re-reads from its database on every `session/list`. 🚫 Sessions started in the Hermes CLI or desktop app: Hermes's ACP `session/list` returns only sessions whose source is `acp` (read in the v0.21.5 source, not verified live). |
| DeepSeek | 🚫 Sesori starts DeepSeek with a bridge-owned `--state-dir`, so sessions a DeepSeek CLI keeps in its own state are not in the store Sesori lists. |
| Cursor, Copilot, Antigravity | Not verified: the time is the ACP `session/list` `updatedAt` each harness reports. |

### Opening a session

Opening a session the store already holds asks its harness for that one
session's activity time without starting the harness. When the time is newer
than what the store caught up to, the open shows the stored transcript at once
and the bridge re-reads the session in the background. The turns run in the
harness's own terminal are then appended without a pull. Otherwise the store is
served with the harness untouched. Only apps that send `backgroundRefresh` get
the check; older apps wait for the re-read as before. Store-only reads and
older pages skip the check.

| Harness | Status |
|---|---|
| Claude Code | ✅ Root sessions: the same tail-record time the catalog scan reads, from the one transcript named for the session. Sub-agent sessions are not checked. Verified live on `2.1.323` (2026-11-12): a `claude -p -c` turn made while the bridge was stopped appeared on the first open after restart, with no pull. |
| Codex | ✅ Rollout modification time, found under the day its UUIDv7 id encodes. A session-index-only change, such as a rename in another client, is not noticed. Verified live on `0.167.2` (2026-11-12) the same way, with a `codex exec resume` turn. |
| OpenCode | ✅ The session's `time_updated` row, from `session_v2` once OpenCode 2.x migrated the database, else `session`. Verified live on `2.2.7` (2026-11-12) the same way, with an `opencode run -c` turn. 🚫 Attach mode (`--no-auto-start`): the attached server need not use the database the bridge would resolve. |
| Pi | ✅ Session file modification time, from the session directory configured for the session's folder. Verified live on `1.5.2` (2026-11-12): a `pi -c -p` turn made while the bridge was stopped appeared on the first open after restart, with no pull. Not supported: a terminal turn in a session that Sesori's own Pi process still holds stays hidden, because the re-read replays that process's history and Pi does not support two writers on one session file. |
| OMP, Grok, Hermes, DeepSeek, Cursor, Copilot, Antigravity | 🚫 ACP reports activity only through `session/list` on a running agent process; there is no bounded read without starting it. Outside turns appear after the next pull. |

## Pending requests on archive

Whatever the harness reports, an archived session never counts as running or
awaiting input in the bridge's activity summary, which every archive refreshes
at once, and the bridge lists none of its pending requests.

| Harness | Archiving cancels the session's own pending requests |
|---|---|
| Claude Code, Codex, Pi, every ACP harness | ✅ Nothing else could answer them once the session is read-only. |
| OpenCode | ⬜ Not implemented: they stay pending in OpenCode's server, which OpenCode's own clients can share, until something answers them there. |

## Requests the harness withdrew

A harness can stop waiting for an approval or question without Sesori
answering it: another client answered it, or an interrupted turn abandoned it.
Where the harness says so, Sesori retires the card the same way as an answered
one and sends nothing back. Every ACP harness also retires what a session still
has pending when the agent answers that session's prompt, since an ended turn
cannot be waiting on the user; this covers requests abandoned silently.

| Harness | Status |
|---|---|
| Codex | ✅ `serverRequest/resolved {threadId, requestId}` retires the request with that exact JSON-RPC id. Verified live on `0.167.2` (2026-11-12): interrupting a turn with a pending command approval sends it with the approval's id, and on `0.167.1` the app's approval sheet closed in the same run. |
| Pi | ✅ For a select, confirm or input dialog with a timeout, Pi resolves the dialog itself when it expires; the plugin runs the same timer and retires the card without answering. Editor dialogs have no Pi timeout: the plugin's own timer answers Pi `cancelled`, which is a cancellation, not a withdrawal. |
| Copilot | 🚫 `1.0.109` sends no withdrawal for a pending ACP permission request when its turn is cancelled. Verified live (2026-11-12): after `session/cancel` the prompt ends `cancelled` and the open `session/request_permission` gets no `$/cancel_request` or other notice. Its runtime has no `$/cancel_request` string. Sesori's own stop already retires the card; one abandoned any other way closes when its turn ends (shared ACP turn-end rule), or on stop, close, delete, archive or connection disposal. Other ways a Copilot turn can end were not probed. |
| OMP | ✅ ACP `$/cancel_request {requestId}` retires the request with that exact JSON-RPC id; the handling is shared by every ACP harness. Verified live on `18.19.0` (2026-11-12): steering into a turn with a pending approval sends it for the approval's id, then OMP fails the tool call and finishes the turn. `session/cancel` sends nothing, and OMP has no approval timeout; Sesori's own Stop already retires the card. |
| Claude Code | ✅ `control_cancel_request {request_id}` retires the `can_use_tool` ask (or elicitation) with that request id. Source only, not run live (`2.1.322` bundle): the CLI sends it when the ask's abort signal fires, that is a turn interrupt, a `PermissionRequest` hook in the user's settings deciding first, a Remote Control answer, or a permission recheck behind a server-side flag. It has no ask timeout for stdio hosts. |
| OpenCode v2 | ✅ An answer from any client arrives as `permission.replied` and retires the card. An interrupt drops pending permissions with no reply event, so `session.execution.interrupted` (reason user, superseded or inactivity) retires every pending permission of that session, which also covers Sesori's own Stop. Verified live on `2.2.7` (2026-11-12): after the interrupt a late reply gets `404`. OpenCode has no permission timeout. |
| OpenCode v1 | Not verified: it announces each reply through its own events, whichever client answered. What an interrupt does to a pending permission was not probed. |
| DeepSeek | ✅ Already handled: the adapter's `deepseek/input/cancel {sessionId}` retires every pending request of the session when a turn is cancelled, a session stops or a sub-agent is interrupted. It never withdraws a single `session/request_permission` and has no timeout. Source only, not run live (`0.2.2`). |
| Hermes | 🚫 `0.23.1` sends no withdrawal. Verified live (2026-11-12): after `session/cancel` it fails the real tool call and the prompt ends `cancelled`; Sesori's own Stop already retires the card. When its own approval timeout fires (`approvals.timeout`, default 300 s) or another Hermes viewer answers, it only fails the tool call, whose id differs from the permission's synthetic `perm-check-N` id, and the turn goes on. That card stays until the turn ends, which retires it through the shared ACP turn-end rule, or until Stop, delete, archive or disposal; an answer before then is dropped. |
| Grok | 🚫 `1.0.77` sends no `$/cancel_request`. Verified live (2026-11-12): `session/cancel` sends its own `interaction_resolved` for the tool call and the prompt ends `cancelled`; Sesori's own Stop already retires the card. Its 600 s client-permission backstop did not fire on Sesori's `--no-leader stdio` launch in 660 s. |
| Cursor | 🚫 `2026.11.11-b912975` has no request withdrawal or permission timeout. Source only, not run live: its ACP client has no `$/cancel_request`, and a cancelled prompt leaves the request open. Sesori's own Stop retires the card, and any card still pending closes when the turn ends (shared ACP turn-end rule). |
| Antigravity | 🚫 `1.4.5` has no request withdrawal or permission timeout. Source only, not run live: a cancelled turn drops its pending request without a message. Sesori's own Stop retires the card, and any card still pending closes when the turn ends (shared ACP turn-end rule). |

## Stop on archive

Archiving a running root session first runs the bridge's Stop with `stop` (the turn and its running sub-agents),
waits up to five seconds, then archives whatever the outcome; a failed, refused or slow stop is logged and the
backend may finish cancelling after the archive. The app's own follow-up stop of busy descendants is not
repeated, so the reach is each harness's own Stop, per [Sub-agents](#sub-agents). A worktree cleanup the
archive would refuse is refused before the stop, leaving the session running.

| Harness | Archiving a running session stops it |
|---|---|
| Claude Code | ✅ `interrupt` stops background sub-agents with the turn. |
| OpenCode v2 | ✅ The root and its working sub-agents at any depth. |
| OpenCode v1 | ✅ The root and its running direct children; a background grandchild keeps running under the archived root. |
| Codex | ✅ The root and its known running descendants, one `turn/interrupt` each. |
| Cursor | ✅ One root `session/cancel`, which cascades; its 20-second settle wait outlasts the archive's 5. |
| Grok | ✅ The root and a snapshot of its running descendants. |
| DeepSeek | ✅ Native subtree stop. |
| Pi, and Antigravity, Copilot, Hermes, OMP (no sub-agents exposed) | ✅ The turn. |

## Pre-start catalog import

| Capability | OpenCode |
|---|---|
| Metadata-only import before harness startup | ✅ |

OpenCode can read a safely identified local SQLite database as a coherent,
read-only snapshot. The reader consumes the OpenCode 1.x project,
project-directory, and session schema (verified on 1.18.19) and safely falls back
to live import when that contract is absent or invalid, or when OpenCode 2.x has
migrated the database. Other harnesses retain their existing
plugin-backed import; no pre-start capability claim is made for them.
All harnesses cold-started only by import fallback or by session options
discovery use the shared five-minute transient idle residency cap.

## Option pickers

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Effort variants listed strongest first, default declared separately | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⬜¹⁷ | ✅ | ✅ | ✅ | ✅ |
| Anthropic and OpenAI models listed strongest first | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫¹⁸ | ✅ |

The picker shows each plugin's declared order. Every plugin ranks through the
shared `CatalogStrengthOrder`; models of other vendors keep the plugin's own
order after the ranked ones (OpenCode newest release first, others backend
order). Antigravity's account-advertised order remains for its unranked models.
Exact account IDs ending in `-high`, `-medium`, or `-low` become strongest-first
variants only when labels carry the matching suffix. Its pre-chat catalog uses
one retained hidden no-prompt native session because the pinned runtime exposes
models only from new/resume responses and has no deletion capability.

Antigravity uses the official `1.4.5` pair and a plugin-owned Zed compatibility
identity (`clientInfo.name: zed`, title `Sesori Bridge (Zed compatibility)`) for
live, replay, personal-login and validation processes. Google's packaged model
selection filters non-Gemini models in `1.2.1`; `1.3.0` through `1.4.5` retain them only for
recognized client identities. Every account-advertised Gemini, Claude or GPT
model is mapped under the existing Antigravity OAuth provider and dispatched
with its exact native ID. Synthetic mixed-provider catalogs and initialize
requests are tested; native authenticated catalog/third-party execution is
unverified. Actual availability still depends on Google's account entitlements.

## Fast mode

| Harness | Status |
|---|---|
| Codex | ✅ Implemented. |
| Claude | ✅ Implemented for the Opus models the CLI reports as supporting it; fast turns draw on the account's extra usage. |
| Hermes | ⬜ Not implemented. Hermes 0.23.0+ offers a service-tier `configOptions` entry for models that support fast mode (read in the 0.23.1 source, not verified live). |
| OpenCode, Antigravity, Copilot, Cursor, Pi, OMP, DeepSeek, Grok | ⬜ Not implemented (not assessed). |

Codex advertises fast mode per model as a `model/list` service tier: a model
offering a `serviceTiers` entry with id `"priority"` (Codex's "Fast" tier, e.g.
"2x speed, increased usage") reports `PluginModel.fastMode` as available with
a 30-minute prompt-cache lifetime; Codex has no account-level availability
signal. A selected
session's `fastMode` is sent as `serviceTier` on every `turn/start` —
`"priority"` when on, `"default"` when off, which explicitly returns the
thread to standard speed rather than leaving it on whatever tier a prior turn
set (verified against codex-cli 0.156.1's `generate-json-schema` output: the
sibling `TurnStartParams.serviceTierForTurn` field documents 'Use "default"
for standard speed', and `serviceTier` shares the same tier vocabulary) — and
on `thread/start` when a new session is created with fast mode on, so its
first turn already runs fast.

Claude Code reports fast-mode support per model as `supportsFastMode: true` in
the stream-json `initialize` response (omitted for models without it; in CLI
2.1.281 only some Opus models carry it), which sets `PluginModel.fastMode` with a
60-minute prompt-cache lifetime. Fast mode is not a launch flag: a fresh process
starts with it off, and the plugin sends the `apply_flag_settings`
control request (`{"subtype":"apply_flag_settings","settings":{"fastMode":…}}`, the shape the Agent SDK's `applyFlagSettings` sends) before a turn whenever the session's choice
differs from what the resident process last applied. The CLI acknowledges the
setting even when the model or account cannot use fast mode (for example, extra
usage turned off) and then serves at standard speed. The plugin reads the
handshake's account-level `fast_mode_disabled_reason` and reports those models
as unavailable with a closed reason: extra usage disabled (`extra_usage_disabled`),
not on the plan (`free`), disabled by the organization (`preference`,
`model_not_allowed`), or unknown (`not_first_party`, `disabled_by_env`,
`unknown`, and unmapped values, which are logged). In CLI 2.1.281 the
`sdk_opt_in_required` reason precedes the account checks and masks them, so the
global catalog probe opts in with `apply_flag_settings {fastMode: true}` and
sends a second `initialize`, whose reason is the real account state (verified
live: `sdk_opt_in_required` became `extra_usage_disabled`). The flag is
process-scoped (no settings file changes) and the probe is torn down afterwards.
Only the probe feeds the catalog; user-session handshakes are never used for
availability. If the opt-in or re-read fails, the failure is logged and fast
mode stays offered. The transient `network_error` and `pending` reasons also
keep it offered, with a log. Per-turn reasons from result messages are not tracked.

## Agent selection and harness modes

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Agent choice offered in the composer | 🚫 | ✅ | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| Harness mode control (for example Plan or Ask) | ⬜ | ✅ | 🚫 | ⬜ | ⬜ | ⬜ | 🚫 | 🚫 | ⬜ | 🚫 | 🚫 |

Only OpenCode has real agents, and its plan agent is how its mode is chosen.
The composer shows the agent entry only when a harness advertises more than
one selectable agent, so it appears for OpenCode alone. Claude, Codex,
Copilot, Cursor and OMP have modes such as Plan and Ask that Sesori used to
list as agents; since 2026-09-21 each advertises only its default mode
(Cursor always its Agent mode) and Sesori offers no mode control. A mode name
that still arrives from a stored session or new-session default, or from an
app older than v1.8.3, is honoured, never run in the default mode. Naming the
advertised default returns a session left in another mode to the default with
its next prompt.

## Read-only run details

Child sessions and archived sessions cannot prompt, so where the composer would
sit they show the agent, model and effort variant the session ran with as
read-only pills. A value Sesori does not know leaves its pill out. The agent
pill follows the composer's rule and appears only for a harness with an agent
choice; every other harness stamps a placeholder agent. What a child session
shows (verified from plugin code on 2026-09-26):

| Harness | Agent | Model | Variant |
|---|---|---|---|
| Claude | ⬜ placeholder | ✅ | ✅ after a history read |
| OpenCode | ✅ | ✅ | ✅ |
| Codex | ⬜ placeholder | ✅ from history | ✅ from history |
| DeepSeek | 🚫 | ✅ live, 🚫 after a restart | 🚫 |
| Grok | ⬜ placeholder | ✅ live, unverified from history | Unverified from history, 🚫 live |
| Cursor | ⬜ placeholder | ✅ live when Cursor announces it, 🚫 after a restart | 🚫 |
| Pi (forks) | 🚫 | ✅ | ✅ |

Antigravity, Copilot, Hermes and OMP produce no child sessions.

- Claude, Codex and Grok record the sub-agent's type natively, but it only
  labels the parent's subtask tile.
- Claude streams no effort, so a child seen only live names no variant until
  the bridge reads its history. A model the catalog does not list shows its raw
  id.
- OpenCode leaves the variant pill out when the child ran without one. Right
  after a child compacts, its agent reads `compaction` until its next reply.
- Codex takes a child's model and effort from its rollout's `turn_context`. A
  running child whose rollout is not flushed yet is stamped live with the
  `config.toml` default model until its history is read again. A turn that
  recorded no effort shows no variant.
- DeepSeek's protocol records no model or effort for a child. A child seen live
  carries the root's model at spawn, which is the model the adapter runs it on.
  After a bridge restart its history is stamped with the process default, so
  the model pill shows a guess.
- Grok names a child's model at spawn. History values come from the child's
  `session/load` and have not been checked against a live child.
- Pi has no sub-agents. A session forked in Pi records its parent, so it opens
  as a child session.

Archived sessions of every harness show the agent and model of their newest
agent reply. Archiving clears the bridge's stored defaults and a reply records
no variant, so the variant pill never shows (⬜). Display names and the
OpenCode agent choice come from the cached option catalog, so opening an
archived session never wakes its harness. Without a cached catalog the model
shows its id and the agent pill is left out.

## ACP multi-select form questions

| Harness | Sesori implementation | Verification boundary |
|---|---|---|
| OMP | ✅ Live ACP `items.anyOf` string-choice arrays render as checkbox questions; a choice and its paired "other" text property render as one question with an "Other" field; the schema default arrives selected; other string, number and integer properties render as separate custom-text questions (numbers parse back to JSON numbers) | Mapper, OMP plugin, shared bridge contract, and widget tests pass; live `18.19.0` built-in `ask` roundtrip on 2026-11-12 through the headless iOS simulator: default accepted, another option, "Other" text and decline each reached OMP as sent |

Property keys, order, independent required flags, and option/custom provenance
are retained, including identical submitted text in separate questions.
Optional omission uses the existing per-question decline in multi-question
forms; single-question decline still rejects the request. Catalog/cleanup
scratch connections do not advertise form support. Other plugins keep their
existing question channels and capability policy; this change makes no new
upstream-support claim for them. See [question regression coverage](regression/questions-and-permissions.md)
for the supported array shape and remaining live check.

## Codex question input

**Implemented:** Codex synchronous user-input requests and asynchronous
assistant-message questions use the existing Sesori question UI and reply API.
Both preserve multiple questions and ordered choices. Async answers steer a
running conversation or resume it while idle; the immediate tool acknowledgement
does not answer the question. Async message metadata was verified against Codex
0.153.4. Older runtimes continue to use their synchronous request path.

**Not implemented:** Masked secret-question entry. Codex requests containing an
`isSecret` question receive an explicit unsupported-input error before any
question card is shown; secret prompts are never downgraded to plain text.

## Setup detection

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Logged-out backend reported as `authenticationRequired` | ✅ | 🚫¹² | ✅ | ✅ | ⬜¹³ | ✅ | ✅ | ✅¹¹ | ✅¹⁴ | ⬜¹⁵ | ✅¹⁶ |

`inspectSetup` owns this state. Where a plugin does not probe credentials it
returns `PluginSetupReady` as soon as it resolves a runtime, so a harness that
is installed but logged into nothing is shown as ready and fails at session
start instead. Sesori-managed installs make this visible: installing the
runtime never authenticates it.

A probe belongs here only when it answers "can this harness serve a turn right
now" without starting a backend or initiating authentication. Counting stored
credentials is not equivalent: a harness with bundled free models or an
environment-supplied key is usable with an empty credential store, and blocking
those installs is worse than the stale ready state this capability replaces.

The marks above cover setup inspection only. A plugin that raises
`PluginAuthenticationRequiredException` while running blocks further starts and
moves the slot to the state its `recovery` selects: `authenticationRequired` for
`login`, `unavailable` for `externalConfiguration`. Copilot raises it with
`login` and the `copilot login` hint after a failed ACP `authenticate`. Claude
raises it with `externalConfiguration` when the gateway behind a custom base URL
rejects a turn, so no login is offered. DeepSeek reports a
provider with no models only as an `authenticationRequired` session-options
result, which leaves the slot unchanged. While a slot is blocked this way,
`GET /plugin` keeps listing the harness with `failureBlock`
(`authenticationRequired` or `unavailable`) and the setup's hint, so the new
session picker can offer it with its blocked notice and Check setup; a harness
that inspection alone reports blocked stays out of that list. The listing lasts
from the shutdown the failure starts until a setup check no longer reports the
login or access refused. This applies to every
harness that raises the exception.

## Managed runtime platform coverage

| Capability | Harness | Sesori implementation | Native verification |
|---|---|---|---|
| Windows ARM64 managed installation | OMP | Implemented: official `omp-windows-arm64.exe`, pinned digest and existing direct-binary install path | Not run for `18.19.0`; install/version/ACP/teardown still needs a native ARM64 host |

OMP's eight mappings retain separate Linux glibc/musl binaries and macOS/Windows
architecture selection. This implementation status is not a native verification
claim. See [runtime installation regression coverage](regression/plugin-runtime-installation.md)
for the platform checks and existing PATH/explicit-binary policy.

## Login initiation

Login is separate from detecting a logged-out backend or installing its runtime.
This table records the current **Sesori-initiated harness/provider login action**,
not login to the Sesori account. "Not implemented" means no such Sesori action;
it does not claim an unprobed upstream ACP/RPC login API is supported or unsupported.

| Harness | Login initiated from Sesori | Current local alternative/setup |
|---|---|---|
| Claude | Implemented: claude.ai pasted-code login on mobile and desktop | `claude auth login` on the bridge machine remains an alternative. |
| OpenCode | Not implemented | Local `opencode auth login` or provider configuration. |
| Codex | Implemented: ChatGPT device-code login | Local Codex login/configuration remains an alternative. |
| Copilot | Not implemented | `copilot login` on the bridge machine. |
| Cursor | Not implemented | Local Cursor CLI login, or `CURSOR_API_KEY`. |
| Hermes | Not implemented | Configure the provider/model through `hermes setup` or `hermes model`. |
| Pi | Not implemented | Run `pi` locally and use `/login`, or configure supported provider credentials. |
| OMP | Not implemented | Run `omp` locally and log into/configure a provider. |
| DeepSeek | Not implemented | Local provider setup; adapter `check` verifies readiness. |
| Grok | Not implemented | `grok login` on the bridge machine. |
| Antigravity | Implemented: automatic personal Google browser OAuth on mobile and desktop | No copy/paste fallback; current client required. |

Claude, Codex, and Antigravity implement `InteractivePluginAuthenticationDescriptor.authenticate`.
Claude drives `claude auth login --claudeai` on the bridge: the user opens the sign-in page from the app and pastes the
code it shows, for claude.ai subscription accounts only. The login sets `BROWSER=true` to keep the host browser closed,
which is verified on macOS but not on Windows, where the host may still open a sign-in tab. See
[Claude Code authentication](regression/claude-code-authentication.md).
Codex uses the existing Sesori device-code UI; Antigravity implements automatic browser return. Current iOS/Android
clients use a system authentication browser and nonce-only app return; remote desktop uses exact loopback capture and
a static return page, while desktop connected to its exact supervised bridge lets the bridge receive callback directly.
Browser kickoff survives settings dismissal, retained phases replay on reopening, and the one callback-listener lifetime
is bounded to five minutes. Browser operations use identity handles bound to their bridge connection and provider/MCP
purpose. A competing flow returns busy without replacing the first listener; retry and cleanup require its owner.
A busy provider challenge remains available for explicit retry. Launch failure can reuse its own live listener;
local direct-browser ownership lasts until native settlement or bounded expiry.
Synthetic iOS Simulator and Android emulator coverage proves raw loopback-to-app return; real Google OAuth remains a
manual verification gap. It permits personal Google OAuth only, suppresses
the bridge host's browser, and uses the same isolated profile for login and live
sessions. Ambient Google login is not imported. Neither row is a general API-key
entry form or a claim of support for every provider authentication method.

Antigravity deliberately omits every persistent `allow_always` choice because
Sesori's current permission contract cannot safely represent persistent approval.
Independently, it excludes any choice of any kind carrying a non-null
`agy.security.warning`, because the warning cannot cross the current contract.
Only unambiguous warning-free `allow_once` and optional `reject_once` choices are
shown. Enterprise OAuth, Gemini API key, and Agent Platform authentication are
not implemented; no upstream support limitation is asserted for those methods.

Local login/configuration must apply to the profile/environment used by that
bridge's harness. Provider keys and local/free models may make a backend usable
without an OAuth login. Setup detection above does **not** imply that Sesori
can initiate login, and managed installation does **not** authenticate a harness.

## MCP management native evidence

Phone and desktop share MCP inventory, server details, connection controls,
native sign-in, credential forgetting, typed forms and URL requests. Clients
show only the controls a plugin declares. Behavior, lifecycle and the
qualification matrix live in
[MCP management regression coverage](regression/mcp-management.md); this section
records the per-harness gaps. Evidence comes from isolated macOS arm64 native
fixtures (2026-10-13 to 2026-10-15) at the versions named below. Real providers,
packaged clients, relay modes, Linux and Windows hosts and the final L4 matrix
remain unqualified, and native recording is deferred. See the
[versioned contract evidence](../.plan/completed/mcp-management/evidence/native-contracts.md)
and [reproduction tools](../tool/mcp-contracts/README.md).

| Harness | Inventory | Reconnect, enable, disable | Sign-in and credential forgetting | Offered connectors |
|---|---|---|---|---|
| Claude | ✅ Live resident session; ⬜ project and harness scope | ✅ Live process only; no configuration write | ✅ Native-configured HTTP servers; ⬜ SSE servers and Windows; 🚫 stdio | ⬜ |
| Codex | ✅ Exact session and harness; 🚫 project scope | 🚫 Not in the native API | ✅ Sign-in; 🚫 forgetting | ✅ Native `app/list` with a setup handoff |
| OpenCode v2 | ✅ Project and exact session location; harness scope unavailable | ✅ Location effect | ✅ Servers with an `integrationID`; 🚫 others | 🚫 No catalog in the v2 MCP API |
| OpenCode v1 | ✅ Project and exact session directory; harness scope unavailable | ✅ Project effect | ✅ Remote servers with OAuth enabled; 🚫 local, OAuth-disabled and unknown types | 🚫 Not in this seam |
| Pi | 🚫 No MCP method in the resident RPC | 🚫 | 🚫 | 🚫 |
| Antigravity, Copilot, Cursor, DeepSeek, Grok, Hermes, OMP | 🚫 Standard ACP has no management API | 🚫 | 🚫 | 🚫 |

Plugin descriptors declare the inventory scopes above (`mcpScopes`). With a
bridge that reports them, harness settings show the MCP entry only for a harness
that answers harness scope, which today is Codex alone, and the session menu
shows it only for a harness that answers session scope (Claude, Codex and
OpenCode), so Pi and the ACP harnesses show none. An older bridge omits
`mcpScopes`, so every harness keeps the entries it had before.

Typed MCP forms and URL requests are implemented for Claude and Codex only;
other plugins return empty snapshots and refuse typed replies.

- **Claude** (2.1.221 and 2.1.291): sign-in runs the CLI's terminal login, since
  plain-pipe login lacks the no-browser journey; the Linux terminal path is
  unqualified. Dynamic or unknown session configuration needs native setup.
  Forgetting keeps server definitions, though the CLI may update its own
  bookkeeping. Status omits tool descriptions. Approval frames carry `mcp_server`
  context, and URL requests work, only from 2.1.291; 2.1.221 rejects URL
  requests before forwarding.
- **Codex** (0.139.0 and 0.160.1): 0.139.0 reports no runtime status, discovery
  error or endpoint origin, which stay unknown, and omits legacy `enumNames`, so
  form labels show native values (`oneOf` titles work on both). Session sign-in
  needs 0.160.1 or later, because 0.139.0 ignores the login thread and picks the harness
  issuer; harness sign-in works on both, with harness-scoped credential effects.
  There is no MCP attempt ID or cancel RPC, so an attempt holds ownership until
  native settlement or teardown. `config/mcpServer/reload` keeps the resident
  tool call on its old connection, so it is not reconnect. Unauthenticated
  `app/list` returned an empty catalog; real offers, setup and entitlement are
  unqualified.
- **OpenCode v2** (2.0.11 and 2.0.24): sign-in also needs exactly one form-free
  OAuth method. Sign-in and forgetting affect the native harness profile.
- **OpenCode v1** (1.14.17, the earliest published 1.14.x since the 1.14.0 floor
  has no artifact, and 1.17.7): client registration, unsupported callback
  overrides and malformed remote URLs need native setup. Sign-in completes only
  by manual callback delivery to the native code-only API. 🚫 There is no
  credential-preserving cancel or pending-status seam: denial callbacks are
  rejected and the attempt holds ownership until native completion or runtime
  retirement. An already-authorized start completes on 1.17.7 but returns a
  serialization failure on 1.14.17, which stays uncertain until retirement.

### Secondary MCP source and adapter audit

Audited from source on 2026-10-15 and not re-audited on later pins. Pi's
[0.99.0][pi-mcp-rpc-min] and [1.0.4][pi-mcp-rpc-target] RPC types expose no
structured MCP management method. The bundled `/mcp` command stays usable (see
"Command limitations"), but its [login][pi-mcp-extension] opens the browser on
the bridge host and its [CLI list][pi-mcp-cli] connects servers in a fresh
process, so neither serves resident inventory or Sesori-owned sign-in.

In the [ACP protocol-1 schema][acp-mcp-schema], `mcpCapabilities.http` and
`.sse` and the server definitions that `session/new` and `session/load` take
describe accepted transports only, not inventory, controls, OAuth or connector
discovery; Sesori passes an empty `mcpServers` list. Vendor extensions and
separate native CLIs are not implemented or audited, so this does not claim
those harnesses lack MCP internally.

[pi-mcp-rpc-min]: https://github.com/earendil-works/pi/blob/4b060d3a98618019adb9985d517516c8e99a2bbe/packages/coding-agent/src/modes/rpc/rpc-types.ts
[pi-mcp-rpc-target]: https://github.com/earendil-works/pi/blob/7c10bd4337495ee613f2224843ecdf349b80d1df/packages/coding-agent/src/modes/rpc/rpc-types.ts
[pi-mcp-extension]: https://github.com/earendil-works/pi/blob/7c10bd4337495ee613f2224843ecdf349b80d1df/packages/coding-agent/src/extensions/mcp/index.ts
[pi-mcp-cli]: https://github.com/earendil-works/pi/blob/7c10bd4337495ee613f2224843ecdf349b80d1df/packages/coding-agent/src/extensions/mcp/cli.ts
[acp-mcp-schema]: https://github.com/agentclientprotocol/agent-client-protocol/blob/59fdb36c3520fe40109e628c48eede5a2a6204df/schema/schema.json

## Context compaction row

The transcript marks a context compaction with a row. Where the harness
reports a start, the row appears live with a timer and settles in place as
"Context compacted" or as a one-line failure note, naming the reason when the
plugin recognizes the harness's error and logging the raw error locally. A
settled row shows the
freed tokens when the harness reports them, marks an automatic compaction when
the harness reports its trigger, and opens the carried-forward summary when the
harness exposes it.

| Harness | Compaction row | Summary |
|---|---|---|
| Claude | ✅ Live from the first `system/status` `compacting` frame, timed from the bridge's stamp of it, settling in place at the closing status's `compact_result`; the summary frame then fills in the details under the same row. A `failed` result becomes a failure note, reading "nothing to compact yet" or "stopped" when `compact_error` says so and no reason for any other error; a failure writes no dedicated compaction record, so the note is gone after a history re-import. Stop or a process exit leaves the running row to the bridge sweep's note. Freed tokens are `pre − post` from `compact_boundary` `compact_metadata` live and the boundary record's `compactMetadata` in history, with the trigger. The transcript keeps no start-time id, so a later re-import re-keys a live row to the summary record's id at the same place, once (verified on 2.1.291). | ✅ The synthetic summary message after `compact_boundary` live, and the `isCompactSummary` transcript record in history (verified on 2.1.291). |
| OpenCode v1 | ✅ Live from the first text of the `summary: true` assistant message, with the newest summary words streamed from its text deltas, settling in place when the message finishes, as completed or as a failure note ("stopped" for `MessageAbortedError`, no reason for any other error; a summary that errors before writing text stays an error message). An automatic trigger (from the compaction marker's `auto`) is shown as "· auto" (a manual one is not named); the freed count is not reported. A compaction that starts during a bridge stream outage shows plain text live until a read reloads the transcript from OpenCode, which maps it to the row in its stored state. | ✅ The text of the `summary: true` assistant message. |
| OpenCode v2 | ✅ Live from `session.compaction.started` once its running snapshot loads (or from the next delta after a bridge reconnect), with the newest summary words streamed from its deltas, settling in place as completed or as a failure note with no reason, because OpenCode's structured error type is free-form. An automatic trigger is shown as "· auto" (a manual one is not named); the freed count is not reported, because the reported tokens are the summary call's usage. | ✅ The completed native compaction message's `summary`. |
| Pi | ✅ Live from `compaction_start`, timed from the bridge's stamp of it (Pi sends no time), staying live while Pi retries and settling in place on success. A terminal failure or abort becomes a failure note, moved off the reserved compaction id, reading "stopped" for an abort, "already compacted" or "nothing to compact yet" for Pi's matching errors, and no reason for any other; Stop or a process exit leaves the running row to the bridge sweep's note. A `threshold` or `overflow` trigger is shown as "· auto" once a live compaction completes; history entries carry no reason. No freed count: Pi reports only the tokens before compaction. | ✅ `compaction_end.result.summary` live and the compaction entry in history (verified on 0.87.1). |
| Codex | ✅ Live from `item/started`, timed from `startedAtMs` or the bridge's stamp, settling in place at `item/completed`. Codex reports no failure, tokens or trigger, so a missing completion is left to the bridge sweep's note and the row has no details. | 🚫 Mostly: live compaction items carry no summary, and remote compaction stores it encrypted, so only a plain rollout `compacted.message` is shown. |
| DeepSeek | ✅ Live only, from `compaction_started`, timed from the bridge's stamp and settling at `compaction_completed`. The statuses carry no ids, tokens, trigger or failure kind, and DeepSeek's history has no compaction record, so the row has no details, a warning or turn end leaves it to the bridge sweep's note, and it survives one history re-import, then disappears. | ⬜ The runtime reports no summary. |
| OMP | ✅ Automatic compaction only, live from `_omp/compaction/start`, timed from the bridge's stamp (OMP sends no time), settling in place at `_omp/compaction/end` as completed with "· auto", or as a failure note reading "stopped" for an abort, "nothing to compact yet" for OMP's benign skip, and no reason for an error (logged locally). A compaction outside a prompt (the opt-in idle compaction) reports the session busy to status reads until it ends, so a history read keeps the row running, but sends no live busy status and so no completion notification; OMP holds a prompt sent meanwhile until it ends. When a method fails and OMP falls back to the next preferred one, the fallback gets its own row under the failure note. No freed count (OMP reports only the tokens before), and the row is live only. 🚫 A manual `/compact` sends no ACP signal, so it shows no row. | ⬜ The ACP notifications carry no summary; what history replay shows of OMP's stored summary was not verified. |
| Antigravity, Copilot, Cursor, Hermes, Grok | ⬜ | ⬜ The ACP session updates Sesori consumes (message, thought and user chunks, tool calls, plan, commands, session info) have no compaction variant, so a compaction, such as Cursor's `/summarize` behind Sesori's `compact` command, arrives as ordinary agent text. A row needs a harness extension signal; none was probed live. |

A row without a summary is inert. Apps at v1.9.0 or older ignore the
compaction state and show no row.

## Command limitations

Pi advertises its bundled `/llama` command over RPC, but the handler supports
only the interactive TUI. Sesori excludes this bundled command source
(`builtin:llama.cpp` since Pi 0.99.0), including numbered invocation aliases,
while preserving user commands with the same name. This command is **not
supported** through Pi RPC; ordinary extension, prompt, and skill commands
remain available. The bundled `/mcp` command stays listed: over RPC it reports
server status and handles `reconnect`, `logout` and `login` through Pi
notifications and an input dialog, although `login` opens its browser on the
bridge host. A sandboxed, credential-free Pi 1.0.4 RPC probe on macOS arm64
(2026-10-06) confirmed both sources, the `/mcp` status reply and the hidden
`/llama`; OAuth sign-in against a real MCP server was not exercised.

## Pi extension startup dialogs

Pi RPC supports extension select, confirm, input, and editor dialogs during
startup through Sesori's temporary startup extension. Catalog probes cancel
these dialogs; session launches use the existing question/reply flow and do not
grant MCP access automatically. Commands buffered during extension startup are
handed back to native RPC unchanged, and native Pi owns later dialogs.

Startup dialog fixtures and catalog discovery were verified on macOS arm64 with
Pi 1.0.4 (npm) and managed Pi 0.85.1 and 0.84.4. Pi 1.0.4 also passed installed
MCP adapter approvals, new/resume/fork RPC launches, and a full Sesori plugin
session completing an authenticated GPT-6.1 request. Pi 1.0.4 awaits
extension startup before reading stdin (not re-probed on the current target
1.5.2 or floor 0.99.0); an unanswered startup dialog can
otherwise exit or hang the process. Sesori forwards startup questions before
waiting for initial history. A runtime already reading stdin uses its own
implementation directly.

## Accepted prompts without transcript output

An accepted prompt must gain a bridge-queue or transcript representation, or
end with `session.prompt-settled` so clients can remove its optimistic row.

| Harness | Status and settlement source |
|---|---|
| Claude | ✅ Command dispatch publishes a correlated synthetic user message. |
| OpenCode v1 | ✅ Correlated backend user echoes cover prompts, commands and manual compaction. |
| OpenCode v2 prompts / fallback compaction | ✅ Caller-supplied native IDs correlate prompt echoes; completed or failed compaction snapshots emit explicit prompt settlement. |
| OpenCode v2 native commands | 🚫 The command route (unchanged from 2.1.4 through 2.2.7) exposes neither caller nor result message identity. There is no correlated echo or explicit settlement; an optimistic command row can remain after acceptance. |
| Codex | ✅ Turn-backed commands correlate their user echo; native `compact` emits explicit prompt settlement because it returns no turn identity. |
| Pi | ✅ User echoes and agent-running fallback synthesis remain transcript-backed; an accepted slash command with no agent work emits explicit prompt settlement after its state barrier. |
| Antigravity, Copilot, Cursor, Hermes, OMP, DeepSeek, Grok | ✅ Shared ACP dispatch publishes a correlated user message; no silent accepted-command path is exposed. |

The explicit event is additive across the client/bridge wire boundary. Older
clients ignore it and converge on refresh; newer clients retain snapshot
reconciliation when connected to an older bridge.

## Failed-turn notices sent as text

Some ACP harnesses end a turn that did no work with `stopReason: end_turn` and
send the reason as ordinary assistant text. The plugin recognizes that text and
shows it as an error notice instead of a reply. Recognition matches the
harness's exact wording, so a reworded notice falls back to plain assistant
text.

The bridge's history store keeps one notice per failed turn. When the live
notice and the replayed one are worded differently, the stored notice shows the
live wording. It adds the replayed wording after it only when the replayed
notice has another error name, that is, when it says something of its own, and
another message id. A replayed notice under the live notice's own id is an
update from the backend, so with another error name its wording replaces the
live one.

| Harness | Sesori availability |
|---|---|
| Cursor | ✅ The account/plan gate ("Check your settings to continue"), live and after history load. |
| Hermes | ✅ The English failure copy Hermes sends as its final response, live and after history load: retries exhausted (including the stream-lifetime cap), first-attempt rate limits, usage limits, rejected credentials, unknown models, content policy, data-policy refusals, billing, the Nous free tier's refusals and outage, loop errors, context overflow, cut-off actions, shutdown, the "No reply:" explanations for exits that fail the turn (a stop on a pending tool result, no answer after all retries, a local context window too small, an error near the iteration limit, repeated errors, and every session-storage failure), a scheduled-job chat, a missing working folder and a chat whose launch API key is gone (in other languages by its untranslated `Details: launch_credentials_unavailable (<field>: <detail>)` line after a one-line notice naming the same key; Hermes's other translated copy stays a plain reply). Hermes saves a different row for a failed turn ("Your request was not processed…", "This turn did not complete. Some actions may already have run…" after a tool ran, or "An automated delivery was interrupted…" for a lost cron or webhook turn, and "This message was refused by the model's safety filter…" for a refused turn); it replays as the turn's notice, so a turn that failed outside Sesori still shows one, and a reload of a turn seen live shows only Hermes's live reason, followed by the row's warning when actions may already have run. Wording read in the Hermes 0.21.5 source on 2026-11-09 and the 0.23.1 source on 2026-11-12. Hermes appends its generic "Your request was not processed…" row to a live reason; Sesori drops it so the notice reads the same live and after a reload. Hermes then fails the prompt with `admitted_turn_failed`, which adds no second notice; when the model streamed part of a reply first, Hermes sends no failure text, so that failed prompt shows as Hermes's own "Your request was not processed…" notice. ⚠️ A reasoning-only stop stays a reply, since it carries the model's last thoughts, and so do the "No reply:" explanations for exits that do not fail the turn (no reply after retries, a partial stream recovered, prior context shown, restart limits, budget or iteration limit reached, an interrupted call). 🚫 Hermes does not report its provider retries over ACP, so such a turn shows "Working…" for about 6.5 minutes before the error arrives. |

Claude Code does not need text matching: it tags a failed turn's assistant
message with an error code, and every code shows as an error notice with Claude
Code's own text. `authentication_failed` also asks for a login (or, behind a
custom base URL, for the gateway's configuration), and `cloud_credential_error`
(2.1.322+) asks the user to fix the cloud provider's credentials on the bridge
machine. `account_on_hold` and `verification_required` (2.1.322+) stay notices,
since neither a login nor setup can clear them.

## Saved prompt files

The bridge core saves every prompt file that doesn't reach the plugin as an
inline image under `~/.sesori/uploads/<sessionId>/` and gives the agent a text
note with the path, the same way for every harness. Grok takes no inline
images, so its images are saved too. Whether the agent can then read the file
depends on the harness, because the folder is outside the session's working
directory, like the local paths Sesori inserts as text when a file is dropped
on a bridge on the same computer:

| Harness | Reads a saved file | Asks first |
|---|---|---|
| Claude Code 2.1.319 | ✅ Quoted it. | Yes: one permission request per read outside the working directory, since Sesori passes no `--add-dir`. |
| Codex 0.167.0 | ✅ Quoted it. | No. |
| OpenCode 2.2.6 | ✅ Quoted it. | No, on a config whose `permission.read` is `"*": "allow"`. The default agent's `external_directory: * → ask` may still ask on other configs; that is unverified. |
| Pi 1.5.0 | ✅ Quoted it. | No. |
| OMP 18.18.2 (ACP) | ✅ Quoted it. | No. |
| DeepSeek runtime 0.2.1 (ACP) | ✅ Quoted it. | No. |
| Grok Build 1.0.30 | ✅ Quoted it. | No. |
| Hermes 0.21.5 (ACP) | Unverified: the file was saved and the note delivered, but the turn never reached a model. | Unverified. |
| Cursor (ACP) | Unverified: the installed CLI (2026.07.23) is older than the 2026.09.23 Sesori requires. | Unverified. |
| Copilot (ACP) | Unverified: runtime not installed. | Unverified. |
| Antigravity (ACP) | Unverified: runtime not installed. | Unverified. |

Checked live on 2026-11-08 from the iOS simulator against a bridge on the same
Mac, reached through the relay, so it counted as remote. Each check sent a
`.txt` holding a known sentence to a new session and asked the agent to quote
it. A permission request is counted from the bridge log. That bridge had YOLO
on, so each request was approved automatically, and in Ask mode it would have
been a prompt. Pi read it on DeepSeek V4.1 Flash, because the machine's OpenAI
login for Pi had expired. Sesori's ACP client advertises
`fs.readTextFile: false`, so ACP harnesses read through their own tools.

## Sub-agents

| Capability | Claude | OpenCode | Antigravity | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles | ✅ | ✅ | 🚫¹⁹ | ✅³ | 🚫⁴ | ✅⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Sub-agent transcripts exposed as child sessions | ✅ | ✅ | 🚫¹⁹ | ✅³ | 🚫⁴ | ✅⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Scoped stop: confirmation while sub-agents run, `stop` cancels them all | ✅ | ✅ | 🚫¹⁹ | ✅ (snapshot)³ | 🚫⁴ | ✅ (root only)⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅ (snapshot)¹⁰ |
| Stop the sub-agents only while the main agent is idle (`stop`) | ✅ | ✅ | 🚫¹⁹ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ✅¹⁰ |
| Stop the main agent only while it runs, keeping its sub-agents | 🚫¹ | 🚫² | 🚫¹⁹ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | 🚫¹⁰ |

ACP plugins declare one closed scoped-stop capability: `unsupported`, `rootSessionCancel` (Cursor),
`perChildSnapshot` (Grok), or `completeNativeAtomic` (DeepSeek). Plugins that report a scoped-stop rejection declare
whether "main agent only" is honored through `mainAgentOnlySupported`; the app offers that action only when it is
true.

¹ Claude Code's only stop primitive (`interrupt`, verified on 2.1.257) stops
background sub-agents together with the running main turn.

² OpenCode's task tool cancels a foreground child when its root is aborted
(verified on 1.18.25); background children survive, and the tracker cannot tell
the two apart, so the option is not offered.
Atomic subtree completion acknowledgment is **not implemented** for OpenCode;
its observed-child snapshot retains legacy client fanout. A v2 stop confirms,
keeps and interrupts working sub-agents at any depth; v1 reaches the direct
children only.

³ Codex (managed codex-cli 0.153.4, probed 2026-09-08): live children announce
through parent activity and status, never `thread/started`; persisted activity
is `event_msg/item_completed/item/SubAgentActivity`, whose item id exactly
matches `spawn_agent.call_id`. Normal initial child input is encrypted in the
rollout and absent from `thread/read`. Live/replayed tiles join by exact
parent-local call ID and use that spawn call's exact nonblank message for the
encrypted-input fallback; they never use parent user history, task names,
labels, order, timing, or the encrypted envelope header. Validated initial
child-owned plaintext `NEW_TASK` can override the fallback. Missing activity
leaves the generic tool card. Native-plugin QA verified forked/nonforked tiles,
cold replay, busy-root handling, and disconnect cleanup. Duplicate display
names, plaintext input, and a differently-terminal resumed child were not run
live. Direct app-server `turn/start` input to v2 sub-agents is **not supported**
by Codex 0.153.4; this does not establish a parent-mediated messaging limit.
Sesori exposes child threads under their direct parent and keeps running
descendants in root busy state. Metadata-only
`thread/read(includeTurns: false)` retains parent and nickname enrichment.
Raw task paths are formatted for display, not used for tile correlation.
`turn/interrupt` works per child with its `turnId`, while parent interrupt
leaves children running, so main-agent-only stop is implemented. Full scoped
stop snapshots the named thread's known running descendants and fans out exact
per-thread interrupts; it is not atomic subtree authority, so accepted results
deliberately report `subAgentsHandled: false` and retain client fallback.
Managed-0.153.4 actual-plugin QA on 2026-09-10 passed its executed scope:
side-effect-free root and named-child confirmation, accurate descendant counts
and named-thread state, root-only `keep`, named-child subtree isolation,
full-root snapshot fanout, authoritative `turn_aborted` for every selected
target, and a surviving runtime. Full-stop targets became non-busy in plugin
status; root `keep` stopped its own turn while effective root status remained
busy for retained descendants. Live matrix is partial: no
pending-input request surfaced, so that case remains automated rather than
live-plugin coverage.
From codex-cli 0.167 a started `subAgentActivity` carries the child's resolved
`model` and `reasoningEffort` (schema dump, 2026-11-12); live child messages
show them as model and effort, as replay already did from `turn_context`. Older
Codex falls back to the child's `thread/read` model and effort, when present.
Live check with an API-key provider on 0.167.1 (2026-11-12): with
`[features] multi_agent_v2 = true` the child session appears and its messages
carry the model; the effort was not exercised because Codex sent no reasoning
effort for the custom model. With `multi_agent_v2` off, Codex's default in
0.167.1, sub-agents arrive as v1 `collabAgentToolCall` items; a completed
`spawnAgent` call with exactly one receiver names the child thread, so the
child session and its subtask tile appear live and in replay (live check on
0.167.2, 2026-11-12). The `<subagent_notification>` user message Codex adds to
the parent when a v1 child finishes is hidden, as the tile already shows it; v2
sends none. In both modes `wait_agent` renders as a "Waiting for N sub-agents" tool row. Sessions whose v1 sub-agents ran before
this mapping keep their generic `Spawn_agent` card, because their child was
never registered.

⁴ Copilot CLI (plugin targets 1.0.109) runs custom agents as subagents. When
probed on 1.0.80, inside the supported range (minimum 1.0.78), its Agent Client
Protocol server exposed no subagent lifecycle, no child session, and only the
turn-wide `session/cancel`. Copilot's changelog says ACP clients receive
subagent IDs since 1.0.81; Sesori has not re-probed on the 1.0.109 pin and maps
no Copilot sub-agent data, so these cells stay 🚫 until a probe confirms usable
sub-agent identity, lifecycle and per-child stop.

⁵ Cursor (PATH minimum `2026.09.23`, managed target `2026.11.11-b912975`;
shapes derived from the CLI bundle on 2026-10-06 and not yet confirmed on the
wire) runs each sub-agent as a native child session once the client sends
`clientCapabilities._meta.subagents: true`, which Sesori always does. A Task
tool call renders no generic card: `subagent_spawned` opens one tile linked to
the child session, and `subagent_state_update` settles it (`completed`,
`failed` as error, `cancelled`, and `disconnected` as error because the outcome
is unknown; an unknown state finishes nothing). The tile's prompt comes from the
Task call's input. Nested sub-agents attach to their direct parent, and a
resumed sub-agent run is a new `<agentId>.<n>` child. Cursor holds the root
prompt open while any sub-agent runs, background ones included, so the root
stays busy until they finish. `cursor/task` requests are acknowledged and
ignored. Reloaded history (`session/load`) keeps its childless tiles for
completed foreground Task calls; only live tiles link a child session.
Unverified: whether loading a child id returns its transcript, whether
`session/list` lists child sessions, and whether pre-capability transcripts
carry `agentId`.
Cursor can cancel only the root: `session/cancel` cascades to every
descendant. A stop on the root while sub-agents run asks for confirmation;
`stop` sends one root cancel, resolves pending input for the root and every
descendant, waits up to 20 seconds, and then fails with HTTP 502 if any
sub-agent is still running. A stop addressed to a sub-agent session is refused
with a "stop the parent session" message before any cancel, and queued prompts
stay. A follow-up prompt while sub-agents run uses the shared stop-and-send, so
it cancels every running sub-agent, background ones included, as on Grok.

⁶ Hermes (hermes-agent 0.19.0) has `delegate_task`, but its ACP adapter
flattens delegation into an ordinary tool call and maps `session/cancel` to a
hard interrupt of the whole agent; no child ids or per-delegate stop cross the
seam. Not re-probed on the supported range (minimum 0.20.0); the plugin still
maps no delegation data.

⁷ Pi (0.84.4) has no native sub-agents. Delegation exists only through
third-party extensions (`pi-subagents`) that spawn separate `pi` processes with
their own control channel, invisible to the RPC stream Sesori drives. Not
re-probed on the supported range (minimum 0.99.0).

⁸ Oh My Pi (18.0.3) has subagents, but its ACP mode maps the task tool to a
generic `tool_call` with no ids or lifecycle notifications; those exist only in
`--mode rpc`, which Sesori does not drive. `session/cancel` aborts the whole
turn.

⁹ DeepSeek's published adapter 0.2.2 over dsh 0.2.2-rc.2 is the managed target;
adapter 0.1.5 remains the minimum accepted runtime. From dsh 0.2.0 a sub-agent
may delegate only one level by default (previously three), with at most eight
active; users raise `subagent.config.maxDepth` in their DeepSeek profile. Provider
settings live in `$DSH_HOME/profiles/sesori/cordis.patch.yml`; `settings.yaml` is
ignored with no automatic import, and a custom provider `baseURL` must speak the
Anthropic Messages API. From dsh 0.2.1 every `subagent` and `subagent_fork`
delegation starts a background child, and the harness lists no models until a
provider credential is configured, so session-option discovery fails with setup
guidance instead of a later failed prompt. ACP uses native subtree stop for the named scope
and every independently resident descendant root, while ordered input cancel,
exact-child authority, lifecycle, tiles, and child catalogs remain native-backed.
Released clients retain their own child fanout. Phone stop/input QA ran only on
adapter 0.1.4, below the 0.1.5 minimum, and has not been repeated on a supported version.
The adapter loads explicitly installed local plugins from only the application-owned
`$DSH_HOME/profiles/sesori` profile on startup, including after `dsh --profile sesori`
rewrites the profile root, then reapplies Sesori's mandatory
runtime constraints; profile changes require restart. A failing optional profile plugin is
skipped with a stderr warning; an invalid profile or failing required row falls
back to the pinned in-memory graph. These plugins are trusted local in-process code, not a
trust grant for future cloud or otherwise managed-trust runtimes.
The native model catalog includes `deepseek-flash` (DeepSeek V4.1 Flash) with
image input and reasoning controls. Refresh rereads the installed harness's
configured catalog; it does not upgrade that harness or fetch a live provider catalog.
Native `web_search` and `web_fetch` tools are enabled: outbound requests occur
when invoked, without a Web BFF, HTTP listener, extra process, or telemetry exporter.

¹⁰ Grok Build (1.0.5, probed 2026-09-03, 2026-09-10, and 2026-09-12) sends
`subagent_spawned`/`subagent_progress`/`subagent_finished` with parent and child
session ids as `_x.ai/session_notification` extension notifications and streams
child updates under the child id. Root `session/load` replays lifecycle as
`_x.ai/session/update`; an unfinished loaded episode can settle later through
`_x.ai/session_notification`, so both remain in the replay drain. Sesori exposes
persisted/live children, loads child transcripts by exact native id, and rebuilds
root tiles from each exact child's first user-message run only when that run is
nonblank, without reading live tracker state. A blank or missing first run
produces no tile; later runs never substitute. Permission denial persistence is
unverified and has no outcome model. Grok scoped stop snapshots the named
scope before mutation, sends root `session/cancel` first, and fans out exact
`_x.ai/subagent/cancel {subagentId}` requests for its running children. This is
not complete native subtree authority: accepted results deliberately report
`subAgentsHandled: false` and retain current-client fallback. Main-agent-only
stop is unsupported because root cancellation stopped every observed child;
idle-root child-only `keep` remains side-effect free. Automated coverage proves
rejection, fanout, outcome mapping, lifecycle-only settlement, and exact pending
permission/queue isolation. Production-composition QA after PR #1429 passed its
executed named-isolation, full-stop, idle-keep/wake, already-finished, replay,
settlement, fresh-session, and runtime-reuse scope; root confirmation reuses an
earlier passing run. That unchanged headless run emitted no permission request.
Subsequent owned-phone QA exercised one genuine request with `Once`; no question
support is claimed. The bounded phone matrix passed creation, tile lifecycle,
exact Stop dismissal and full cancellation, same-session/runtime reuse, cold root
history, and exact read-only child navigation. Final fixed-build QA showed one
stable child-owned initial row plus one assistant/tool/assistant sequence on two
opens. Background completion delivery was attempted, but no OS notification was
observed; notification and push delivery remain unclaimed.

¹⁹ Antigravity's official managed ACP pair (package 1.0.0, runtime
`agy_acp_server_20260818_01_RC01`, probed 2026-09-12) can invoke native internal
sub-agents. Two authenticated default-mode turns returned the expected bounded
reasoning result after `invoke_subagent` activity and one warning-free
`allow_once` decision each. The official ACP projection does not expose a
trustworthy Sesori subtask seam, however: every update carried only the parent
session id; no child session, child id, child lifecycle extension, background
fact, or child-cancel method appeared. Live `invoke_subagent` calls moved from
`pending` to `failed` even though the root reported the delegated result, while
`session/load` replayed those same calls as `completed`, string-encoded their
structured input, and supplied blank raw output. Nested work appeared only as
additional generic parent-local tool calls without correlation to the invocation.
Sesori therefore keeps these calls generic and does not infer tiles, child
history, descendant busy state, or scoped stop from call order, prompt text, or
replay's contradictory status. Standard turn-wide `session/cancel` remains
available, but it cannot implement any sub-agent-specific stop row above. This
is a limitation of the ACP projection Sesori drives, not a claim that native
Antigravity lacks delegation. Not re-probed on the current `1.4.5` pair; the
plugin still maps no sub-agent data. Details:
[completed probe record](../.plan/completed/claude-inline-subtasks/followups/antigravity-probe.md).

¹¹ Pi (0.84.4, probed 2026-09-05) reports it from `pi --list-models`, which
prints one row per usable model and otherwise prints the
"No models available. Use /login…" text that
`PiRpcClient.noModelsDiagnosticPrefix` already matches on the session path, so
an empty listing is the logged-out signal. Listing resolves every credential
source Pi accepts — `~/.pi/agent/auth.json`, inline provider keys in
`~/.pi/agent/models.json`, and environment API keys — which reading the auth
file alone would not: a user carrying only an environment key or a local
provider has no `auth.json` entry and a working install. `pi auth check` is
unusable here because it requires an explicit `--provider` or `--model` and Pi
exposes no global variant. Verified against a fresh Sesori-managed 0.84.2
install with no credentials; not re-probed on the supported range (minimum 0.99.0).

¹² OpenCode (1.18.25, probed 2026-09-05) has no logged-out state to report.
`opencode models` lists the bundled free `opencode/…` models identically with
five credentials and with zero, so an install with an empty credential store
is usable and ready is the correct state for it. `opencode auth list` counts
credentials, but that count is not this capability: reporting authentication
required from it would block working installs. Ready remains correct for
OpenCode regardless of stored credentials.

¹³ Copilot has not been probed for a non-interactive credential check.

¹⁴ Oh My Pi (18.1.10, probed 2026-09-05) reports it from `omp models --json`,
which returns `{"models":[]}` with no credentials and a populated list
otherwise — the same signal Pi exposes, in a structured form. Only a listing
that parses and reports no models downgrades setup: supported releases reach
back to 17.2.13 and `models --json` is not guaranteed across that range, so an
unparsable or failing listing leaves setup ready instead of regressing a
working older install.

¹⁵ DeepSeek already probes readiness in `inspectSetup` but maps a negative
result to `PluginSetupUnknown`, so a logged-out install is reported as
undetermined rather than as authentication required.

¹⁶ Grok Build (1.0.5, probed 2026-09-05) reports it from `grok models`, which
prints `You are logged in with <account>.` or `You are not authenticated.`
ahead of a model list that is identical either way, so the authentication line
is the signal and the listing itself is not one. Only that line downgrades
setup; unrecognized wording leaves setup ready rather than blocking a working
install on a phrase a later release may change.

¹⁷ Hermes 0.19.0 exposed no effort or thinking levels over its ACP seam. From
0.22.6, new and load results carry a reasoning-effort `configOptions` entry
(category `thought_level`), set through `session/set_config_option` (read in
the 0.23.1 source, 2026-11-12). Sesori does not drive it yet, and the 0.20.0
minimum predates it.

¹⁸ DeepSeek model ids are deliberately opaque tokens with no vendor signal, so
its models keep DeepSeek's catalog order; its efforts are ordered.
