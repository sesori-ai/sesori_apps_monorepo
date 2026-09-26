# Step Timers: Step Summaries And Live Timers

## Status

- **Plan slug:** `step-timers`
- **Created:** 2026-09-26
- **Origin:** the user's UX review of 2026-09-26, three rounds on local pages
  (`/tmp/sesori-ux/step-timers/round2.html` for Q1–Q10 and the "What it takes"
  table, `/tmp/sesori-ux/step-timers/index.html` for round 3, Q11–Q12). The
  pages stay local. Every decision below is final and is recorded under
  [Decisions](#decisions); the copy is under [Approved Copy](#approved-copy).
- **Series:** phase 1 is seven PRs. The titles are fixed in
  [TRACKER](TRACKER.md#fixed-pr-titles). Phase 2 is rough intent only. It
  becomes detailed steps in a plan update once phase 1 has retired (see
  [Later Phases](#later-phases-rough-intent-only)).

## Goal

A running session should say how long it has been working, and a finished
step group should say what it did in a line that fits on a phone:

- A step group reads "7 steps · 3m 05s" instead of a per-kind list.
- "Working…" ticks the time since the prompt was sent.
- While only sub-agents work, the transcript says so, with their time, and
  says the user can keep chatting.
- Later: every running step and compaction ticks its own time, and an opened
  group shows each step's time.

Phase 1 is client-only. It needs nothing new from the bridge or the plugins.

## Current Behavior (origin/main at b1d4c57d20, 2026-09-26)

### Client

- `TranscriptBuilder` (`client/module_core/lib/src/cubits/session_detail/transcript_builder.dart`)
  groups tool, thinking and sub-agent parts into a `TranscriptGroupBlock`. Its
  `TranscriptSummary` counts finished steps per `TranscriptStepKind` (thinking,
  read, edit, command, search, tool, sub-agent) plus `failedCount`. The kind of
  a tool step comes from the wire field `MessagePartTool.kind` (`ToolKind`).
- `TranscriptGroupWidget` (`client/module_app_ui/lib/src/features/session_detail/widgets/transcript_group_widget.dart`)
  renders the summary as rolling segments, "Thought · read 2 files · ran 1
  command · 1 failed", with the failed count in red. Since PR #1738 a group
  with exactly one finished step shows that step's own row instead of a
  summary.
- `TranscriptWorkingRow` (`transcript_live_row.dart`) is a sparkle plus a
  shimmering "Working…". `SessionDetailMessageList` shows it in the
  `_kWorkingRowId` slot when `isBusy && retryErrorMessage == null &&
  transcript.liveStep == null && streamingText.isEmpty`.
  - `isBusy` (`session_detail_loaded_view.dart`) is `hasActiveWork(...)` (the
    root is not idle, or any child is busy or retrying) and no question or
    permission waits.
  - `transcript.liveStep` includes a running sub-agent step, so a running
    sub-agent tile hides "Working…". When the main agent has finished its text
    and only sub-agents run, the transcript ends on the main agent's last
    message with nothing live under it.
- The composer's sub-agent pill (`background_tasks_bar.dart`) counts running
  children (`SessionStatusBusy` or `SessionStatusRetry` in `childStatuses`)
  and leads with a `PregoActivityIndicator` spinner.
- Folded turns (turn-navigation, #1763): `TranscriptTurnStub` shows
  "Running · step 3" for the running turn and "42 steps · 1h 05m — answer" for
  a finished one. The running stub has no clock (turn-navigation D16), and the
  "Working…" row still shows under it. Durations format as "42s", "1m 02s",
  "1h 05m" (`TranscriptTurnStub._duration`, strings `transcriptTurnSeconds`,
  `transcriptTurnMinutes`, `transcriptTurnHours`).
- Both shells (`client/app` and `client/desktop`) render the shared
  `SessionDetailMessageList`.

### Wire and bridge

- No message part carries a time. `MessagePartTool`, `MessagePartReasoning`,
  `MessagePartSubtask` and `ToolState` in
  `shared/sesori_shared/lib/src/models/sesori/message_part.dart` have no time
  fields, and neither do `PluginMessagePart` and `PluginToolState` in
  `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart`.
- A message carries `MessageTime{created, completed?}` (epoch ms) from the
  plugin, mapped as is by `bridge/app/lib/src/repositories/mappers/plugin_message_mapper.dart`.
  The bridge never stamps it.
- The bridge stores wire JSON in Drift (`history_parts.partJson`,
  `history_messages.infoJson`). A re-import (`ChatHistoryRepository.replaceSessionMessages`)
  rebuilds part rows from the harness snapshot.
- Shared codegen ignores unknown keys (`any_map`, no
  `disallowUnrecognizedKeys`), so an additive optional field is safe both ways.
  `MessagePart` has no fallback union, so a new part type is not.
- `ToolKind` on `MessagePartTool` was added on 2026-09-25 (visual-hierarchy
  step 32, `76caab4a75`). It shipped only in `v1.9.1-internal.*` builds, never
  in a public release. The client's only reader is the group summary.

### Per-harness facts, verified in code

The review's "What it takes" table was checked against the plugins. Rows
marked **corrected** differ from the table.

| Fact | Finding |
|---|---|
| Codex step times | **Corrected.** Every Codex item is its own message, and live `item/started`/`item/completed` fill that message's `created`/`completed` (`codex_event_mapper.dart`). So live steps have a real start and end, as message times, not part fields. After a reload only the start survives: history takes the rollout line `timestamp` and drops the output record's time (`codex_message_repository.dart`). |
| OpenCode step times | Confirmed. `ReasoningPart.time{start,end}` and the tool state times (running `start`; completed and error `start`, `end`) exist in the generated models and are dropped by `message_part_mapper.dart`, live and after reload. The v2 adapter (not active; opencode-v2 step 7.b pending) drops them too. |
| Claude Code step times | Confirmed. Live `assistant` frames and every transcript record carry `timestamp`, and tool-result `user` frames and records do too. The plugin uses one per message and drops the rest (`claude_event_dispatcher.dart`, `claude_history_mapper.dart`). `tool_progress.elapsed_time_seconds` and `task_progress.duration_ms` are parsed and dropped. Live thinking has no start time (stream events carry none). |
| Pi step times | **Corrected in part.** Pi has no per-thinking time and no timestamp on `tool_execution_*` events. What the plugin drops is the tool end (the `toolResult` message timestamp, live and in history) and history entry timestamps. |
| DeepSeek step times | **Corrected.** Not "no timing": `_meta["sesori.ai/deepseek"].messageCreatedAt` gives each message a real creation time, live and in history, and each tool call is its own message. So tool starts are real; ends are missing. |
| Grok and the other ACP harnesses | Confirmed: no time on steps. Grok's on-disk `updates.jsonl` fixture has a per-line `timestamp` that `GrokPersistedUpdateDto` drops; not verified against real data. |
| Prompt sent time | OpenCode, Codex, Pi and DeepSeek: live and after reload. Claude: after reload from the record timestamp; live it is whatever the CLI's `--replay-user-messages` echo carries, which nothing in the repo verifies, so it may be null (slash commands get a synthetic now). Grok, Antigravity, Copilot, Cursor, Hermes and OMP: never (`localUserMessageTime` returns null). Confirmed. |
| Compaction start | Codex and Pi: confirmed, a running tool part `tool: "compact"` that the client shows as "Compact", replaced in place on completion. OpenCode v1: confirmed, the start is dropped and the "Context compacted" row appears while the summary is still streaming; v2 fixes the early row. DeepSeek: confirmed, `compaction_started` is parsed and dropped. **Claude corrected:** `compact_boundary` arrives after compaction and is used, not dropped; the only candidate start is `system/status` with `compacting`, parsed and dropped, and not seen in the repo's captures. Other ACP harnesses: no signal. |
| Harnesses with sub-agent rows | **Corrected.** The table listed Claude Code, Codex, DeepSeek and Grok, plus OpenCode through its Task step. OpenCode background children also leave the parent idle while they run, so the row applies there too. Cursor shows tiles, but a background Task has no lifecycle and a foreground Task is a running tool step, so the row never shows on Cursor. |
| Main agent continues after sub-agents | Claude: yes (task-notification wake-up). Grok: yes (`will_wake`). Codex: no. DeepSeek: **corrected**, yes natively (September probe on dsh 0.1.1-rc.2 opens a follow-up parent turn), though whether that turn surfaces over ACP is unconfirmed. OpenCode: unverified. No phase-1 copy depends on this any more (Q11 B dropped the promise). |
| Sub-agent start time | No child session carries one on Claude or the ACP plugins (`time: null`). The usable source is the `created` time of the message holding the sub-agent's part: real on Codex, Claude, DeepSeek; null on Grok. OpenCode maps the child session's `time.created`. |

### Can the user keep chatting while sub-agents run?

The second line of the sub-agent row, "You can keep chatting meanwhile.", is
shown only where a prompt sent in that state reaches the main agent at once.
Neither the client nor the bridge queues on busy: the client sends straight to
the bridge, and queuing is the plugin's own choice.

| Harness | Answer | Evidence |
|---|---|---|
| Claude Code | **Yes.** The prompt is written to the CLI at once and starts a turn. Background tasks never force a turn boundary. | `claude_session_service.dart` `_dispatchTurn`, `_requiresTurnBoundary`; `claude_stream_client.dart` |
| Codex | **Yes by code, unprobed.** `sendPrompt` calls `turn/start` at once; the parent's own turn has ended. No live probe has sent to a parent with running children. | `codex_plugin_impl.dart`, `codex_thread_repository.dart` |
| OpenCode | **Yes** for background children: the parent is idle and `prompt_async` starts a turn. A foreground Task is the parent's own running step, so the row does not show. | `opencode_api.dart`, `active_session_tracker.dart` |
| Grok | **Yes.** With the root idle, `session/prompt` goes out at once. Only inside a pending wake hold does a prompt wait, and then the main agent is about to act. | `acp_plugin.dart`, `grok_event_mapper.dart` |
| DeepSeek | **Yes by code, unprobed.** The shared ACP path sends at once after `end_turn`. A prompt that lands during DeepSeek's native follow-up turn is unconfirmed. | `acp_plugin.dart`; `.plan/completed/claude-inline-subtasks/followups/deepseek-probe.md` |
| Cursor, Antigravity, Copilot, Hermes, OMP, Pi | Not applicable: no running sub-agent lifecycle reaches the client, so the row never shows. | `docs/HARNESS_CAPABILITIES.md` Sub-agents |

So no harness where the row can show needs the second line omitted. Step 5
still confirms Codex and DeepSeek live before it ships the line. If either
probe shows a prompt does not reach the main agent, step 5 stops and the plan
gains a plugin-declared capability for that harness (see
[Decisions](#decisions), P9).

## Decisions

The user's decisions of 2026-09-26 (final):

- **D1 Every thinking block and every tool call is one step.** A group reads
  "N steps · <duration>". The per-kind list goes away. No failed count
  (Q1 B).
- **D2 Revert PR #1738.** A lone finished step collapses to "1 step" like any
  other group. The revert lands in the first app PR that changes the summary
  (step 2), including its regression-doc text and tests.
- **D3 A group with a running step holds its time still;** only the running
  step ticks (Q2 A).
- **D4 "Working…" ticks the whole turn** from when the prompt was sent (Q3 A).
- **D5 The running step gets its own timer.** Compaction gets a running row,
  "Compacting context · 1m 42s", that becomes today's "Context compacted" when
  it ends.
- **D6 Step start times (Q12 A):** the real start where the harness or plugin
  reports it; elsewhere inferred as the previous step's end, or the prompt time
  for a turn's first step. The inferred time includes the gap between steps;
  accepted. Steps need a start and end from the bridge, filled by every plugin.
  Harnesses without timing get end times stamped by the bridge as it sees each
  step finish live. All harnesses (feature parity).
- **D7 Sub-agent row.** Shown when the main agent does nothing itself and at
  least one sub-agent runs; hidden while a question or permission waits.
  Spinner icon like the composer pill, never "Working", never the sparkle. Two
  lines (Q11 B): "2 sub-agents running in the background · 3m 05s", then a
  muted "You can keep chatting meanwhile." Its timer counts from when the
  sub-agents started (Q7 B). OpenCode's foreground Task is a running step,
  whose row covers it.
- **D8 Times read "42s", "1m 02s", "1h 05m 12s"**; seconds always show (Q8 A).
- **D9 A folded running turn keeps its folded row without a timer;**
  "Working… · 1m 43s" shows under it (Q9 B; matches turn-navigation D16).
- **D10 An opened group shows each step's own time,** built with the step
  times work (Q10 B).

Planning decisions, from code evidence:

- **P1 Phase 1 derives everything from data the client already has.** The
  Working timer reads the running prompt turn's `opener.info.time.created`.
  The sub-agent timer reads the earliest known start among running sub-agents
  (below). Where that time is missing, the row shows without a timer; no
  client-side "first seen" clock (it would restart on reopen or on another
  device, which the user rejected in Q4).
- **P2 Where the live row's decision lives.** A pure, stateless
  `TranscriptActivityBuilder` in `module_core`, next to `TranscriptBuilder` and
  `TranscriptTurnBuilder`, returns a sealed `TranscriptActivity`:
  `TranscriptActivityWorking({required int? sinceMs})`,
  `TranscriptActivitySubAgents({required int count, required int? sinceMs})`
  or `TranscriptActivityIdle()`. The message list renders it in the existing
  `_kWorkingRowId` slot. The rule moves out of the widget so it is tested
  without pumping the list, and so it stays harness-neutral. Its full input:

  ```dart
  TranscriptActivity build({
    required Transcript transcript,
    required TranscriptTurns turns,
    required List<MessageWithParts> messages,
    required bool isBusy,
    required String? retryErrorMessage,
    required bool hasStreamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
  })
  ```

  `isBusy` stays an input, computed as today by the shell-side
  `hasActiveWork` together with the question and permission gate, so the
  builder never sees pending input. `messages` supplies the `created` time of
  the message that holds a sub-agent step (P4).
- **P3 The activity rule.** With `mainQuiet` = no retry row, no streaming
  text, and no running step other than a sub-agent step, and `running` = the
  running-children count (P10):
  - `isBusy && mainQuiet && running > 0` gives `SubAgents`;
  - otherwise `isBusy && retry == null && streamingText.isEmpty &&
    transcript.liveStep == null` gives `Working` (today's rule, unchanged);
  - otherwise `Idle`.
  "Main agent does nothing itself" is read from the transcript, because the
  root status cannot tell it apart on every harness (Codex and the ACP plugins
  hold the root busy for their children). While the main agent thinks between
  steps with nothing streaming and sub-agents run, the sub-agent row shows
  instead of "Working…". That is the review's stated behavior ("takes over
  from Working… when the main agent goes quiet"); accepted.
- **P4 Sub-agent start.** For each running child: the `created` time of the
  message holding a sub-agent step linked to that child
  (`TranscriptSubAgentStep.childSession`), else the child's own
  `time.created`, else unknown. The row's `sinceMs` is the earliest known one;
  none known gives no timer. In phase 2 the linked sub-agent step's own start
  replaces the message time.
- **P5 One duration formatter.** A single `TranscriptDurationFormatter.format`
  (`module_app_ui`, localized) serves the folded stub, "Working…", the
  sub-agent row and, later, groups and steps. `transcriptTurnHours` gains
  seconds. The formatter clamps a negative elapsed time to 0s: the start is
  the harness machine's clock and the ticker is the device's, and a small skew
  is accepted.
- **P6 One ticking widget.** `TranscriptElapsedTime({required int sinceMs})`
  owns one `Timer` that fires on each whole elapsed second and rebuilds only
  its own text. Only one live timer shows at a time in phase 1 (the two rows
  are exclusive). The timer text is excluded from live-region announcements;
  the row's semantic label carries the elapsed time at build.
- **P7 Remove the tool kind.** D1 leaves `ToolKind` with no reader. It never
  reached a public release, so step 3 removes it everywhere (wire field,
  plugin-interface field, each plugin's classifier, tests and the capability
  section) with no compatibility path. An older internal app reading a newer
  bridge sees `unknown`, which it already treats as a plain step.
- **P8 No harness branch in the client.** Harness differences (missing
  prompt times, missing sub-agent times) show only as a missing timer and are
  recorded in `docs/HARNESS_CAPABILITIES.md`.
- **P9 Contingency for the second line.** Code says the line is true on every
  harness where the row shows. If a step-5 probe contradicts that, step 5
  stops before its PR opens and this plan is updated with a plugin-declared
  capability (its model, wire field and compatibility default) and reviewed
  again before any capability code is written. Nothing is built unless a probe
  requires it.
- **P10 One owner of "running child".** The pill's private `_isRunning`
  (`SessionStatusBusy || SessionStatusRetry`, `background_tasks_bar.dart`)
  moves into `module_core` as a `runningChildren` helper beside
  `session_detail_resolvers.dart`. The pill and `TranscriptActivityBuilder`
  both use it, and the pill's copy is deleted (step 5).

## Explicitly Excluded

- Any wire, bridge or plugin change in phase 1.
- A client-side "first seen" clock for missing prompt or step times.
- A failed count anywhere in the group line (D1). A failed step still shows
  red when the group is opened.
- A clock on the folded running stub (D9).
- Analytics: the timers are passive display and answer no product question
  the existing session events do not.

## Architecture

### 1. Group summary (step 2)

- `module_core`: `TranscriptSummary` shrinks to the finished step count, or is
  replaced by `TranscriptGroupBlock.finishedSteps.length` if nothing else reads
  it. `TranscriptStepKind`, `TranscriptKindCount`, `TranscriptStep.kind` and
  `failedCount` go. `TranscriptTurnSummary.failedSteps` counts failed steps
  directly from the group steps if a reader remains, else it goes too.
- `module_app_ui`: `TranscriptGroupWidget.build` drops the #1738 branch, so
  any finished step shows the summary and running steps stay below it.
  `_SummaryRow` renders one rolling segment, "N steps", so the count still
  rolls when a live row folds in. The red failed line goes.
- `app_en.arb`: keep `transcriptSummarySteps` (new description: every thinking
  block and tool call counts); remove `transcriptSummaryThought`, `…Read`,
  `…Edited`, `…Ran`, `…Searches`, `…SubAgents` and `…Failed`. Regenerate.
- Tests: `transcript_builder_test`, `transcript_group_widget_test`,
  `assistant_message_card_test`, and the desktop screen test #1738 edited.

### 2. Tool kind removal (step 3)

Remove `ToolKind` and `MessagePart.tool.kind` from `sesori_shared`, the
matching `PluginToolKind` field on `PluginMessagePart.tool`, the mapping in
`plugin_to_shared_mapping.dart`, and each plugin's mapping of its tools onto
that output (Claude, Codex, Pi, OpenCode v1 and v2, the shared ACP plugin),
with their tests. Remove only the plugin-interface output. A plugin that uses
a classification for its own behavior keeps a private one:

- Pi's `PiToolTracker.isEdit` decides edit-diff emission
  (`pi_tool_tracker.dart`); it keeps a private edit predicate inside the
  plugin, as Claude's private `_ClaudeToolKind` in `claude_tool_tracker.dart`
  already is and stays.
- ACP-native `kind` values the ACP or Antigravity plugins read for their own
  purposes (for example shell detection or permission presentation) stay. Delete the "Tool kinds" section of
`docs/HARNESS_CAPABILITIES.md`. Regenerate Freezed output.

### 3. Duration format, ticking time and "Working…" (step 4)

- `module_app_ui`: `TranscriptDurationFormatter.format` (P5) and
  `TranscriptElapsedTime` (P6). `TranscriptTurnStub` uses the formatter.
  `transcriptTurnHours` becomes "{hours}h {minutes}m {seconds}s".
- `module_core`: `TranscriptActivityBuilder` (P2) with only the `Working`
  and `Idle` variants in this step. `Working.sinceMs` is the running prompt
  turn's opener `time.created` (the last turn from `TranscriptTurnBuilder`
  when it is a `TranscriptPromptTurn` with `TranscriptTurnRunning`); null for
  a headless segment or a missing time.
- `SessionDetailMessageList` renders the activity in `_kWorkingRowId`.
  `TranscriptWorkingRow` takes `sinceMs` and appends " · " plus the elapsed
  time when it is known. Under a folded running turn the same row shows, so D9
  needs no extra code.
- The snapshot held while the reader is scrolled away keeps its activity; the
  elapsed time keeps ticking from the fixed start, which is correct.

### 4. Sub-agent row (step 5)

- `module_core`: the builder gains `SubAgents` (P3, P4), and
  `runningChildren` moves here from the pill (P10).
- `module_app_ui`: `TranscriptSubAgentsRow({required int count, required
  int? sinceMs})`, in the same slot and presence column, so the handover with
  "Working…" eases as today. Leading slot: a `PregoActivityIndicator` sized to
  the sparkle slot, as the pill uses. First line: muted text without shimmer,
  the count label, then " · " and the elapsed time when known. Second line:
  "You can keep chatting meanwhile." in the tertiary text colour.
- New strings: `transcriptSubAgentsRunning` (plural) and
  `transcriptSubAgentsKeepChatting`.

## Approved Copy

| Where | Copy |
|---|---|
| Group summary | "1 step", "7 steps", later "7 steps · 3m 05s" |
| Working row | "Working… · 1m 43s" (plain "Working…" when the prompt time is unknown) |
| Sub-agent row | "1 sub-agent running in the background · 3m 05s" / "2 sub-agents running in the background · 3m 05s", then "You can keep chatting meanwhile." |
| Compaction (phase 2) | "Compacting context · 1m 42s", then "Context compacted" |
| Durations | "42s", "1m 02s", "1h 05m 12s" |

## Security And Privacy

Nothing new leaves the device or the bridge. The timers read times the client
already receives.

## Complexity Budget

Phase 1 adds no persistent state and no wire fields. New in-memory mutable
parts:

- one `Timer` inside `TranscriptElapsedTime`, alive only while a live timer is
  on screen; it owns nothing but its own rebuild.

New immutable pieces: the `TranscriptActivity` sealed type and
`TranscriptActivityBuilder`, `TranscriptDurationFormatter`, the
`runningChildren` helper moved from the pill, and two row widgets. Deliberately not added: a cubit clock or
ticking state, a stored "first seen" time, a per-harness client flag, a
capability field for the second line (P9 only if a probe demands it).

## Cleanup Assessment

- Step 2 removes the per-kind summary: the kind enum and count type, the
  failed count, seven strings, and #1738's lone-step branch, tests and doc
  text.
- Step 3 removes what step 2 leaves without a reader: `ToolKind` across the
  wire, the plugin interface and every plugin, plus its capability section.
  Its own PR, because it touches the bridge and every plugin.
- `TranscriptTurnStub._duration` moves into the shared formatter.
- Nothing else found. The `session.compacted` event the client ignores stays;
  phase 2's compaction row may use or retire it.

## Proportionality And Accepted Risk

- Clock skew between the harness machine and the device shifts every timer
  by the skew; clamped at 0s. Accepted (display only, self-consistent).
- On Claude, a live prompt's time may be null until reload, so "Working…"
  may show no timer for a live Claude turn. Step 4 checks it live and records
  it; the fix is phase 2's bridge prompt stamp, not a client fallback.
- On Grok and the other ACP harnesses "Working…" shows no timer, and on Grok
  the sub-agent row shows no timer, until phase 2.
- P3's takeover while the main agent thinks silently between steps: accepted.
- A child resumed long after it was created counts from its first sub-agent
  step's message (or its creation) until phase 2. Accepted, rare.

## Regression Coverage

Each step updates the documents for the behavior it ships.

| Step | Document changes |
|---|---|
| 2 | `tools-and-file-changes.md`: the group line is "N steps"; remove the lone-step paragraph #1738 added and the per-kind and failed-count text; update the L1 row. |
| 3 | `docs/HARNESS_CAPABILITIES.md`: remove "Tool kinds". `tools-and-file-changes.md`: remove any remaining kind text. |
| 4 | `tools-and-file-changes.md`: the Working timer and the duration format. `transcript-turn-navigation.md` (created by turn-navigation step 6, #1769): durations past an hour show seconds; "Working… · time" under a folded running turn. `docs/HARNESS_CAPABILITIES.md`: new "Live timers" section with the prompt-time column per harness. |
| 5 | `tools-and-file-changes.md` (or `session-turns.md`, whichever owns the Working row after step 4): the sub-agent row, its rule and copy. `docs/HARNESS_CAPABILITIES.md` "Live timers": the sub-agent timer and "keep chatting" columns with the probe results. |
| 6 | Reconciles every document with what shipped. |

Failure signals, added by the step that ships the behavior:

- step 2: a group shows a per-kind list, a failed count, or a lone step's own
  row;
- step 4: "Working…" shows a time that restarts on reopen, runs backwards, or
  differs from the folded turn's duration once it finishes;
- step 5: the sub-agent row shows "Working" or the sparkle, shows while a
  question waits, or claims chatting where a prompt would wait.

**Highest level: L3 Release.** The boundary is client end to end with live
plugins, because the timers depend on each harness's prompt and message times.

Required matrix, recorded now; any reduction needs the user's acceptance in
this file before retirement:

| Platform or plugin | Coverage |
|---|---|
| iOS phone, real device (release target) | Group lines "1 step" and "N steps", with the count rolling as a step folds in; "Working… · time" ticking, surviving an app restart without resetting; the folded running turn with "Working… · time" under it; the sub-agent row and its handover with "Working…"; VoiceOver reads the rows once, not every second. |
| macOS desktop | The same, with the group popover. |
| Android phone | Smoke: group line, Working timer, sub-agent row. |
| Claude Code (live plugin plus client) | Working timer live and after reload (record whether the live prompt has a time); background sub-agent row with timer; a prompt sent while it shows is answered at once. |
| Codex | Working timer; sub-agent row; a prompt sent while it shows starts a parent turn at once (the step-5 probe). |
| OpenCode | Working timer; a foreground Task shows its running step, not the row; background children show the row. |
| Pi | Working timer; no sub-agent row. |
| DeepSeek | Working timer; sub-agent row; a prompt sent while it shows is answered (the step-5 probe). |
| Grok | Plain "Working…" (no prompt time); sub-agent row without timer; prompt while it shows. |
| One other ACP harness | Plain "Working…". |

Automated coverage in the steps: the activity builder's rule table, the formatter,
the ticker with a fake clock, group and row widget tests, and the stub copy.

## Delivery Rules

- **Order.** Step 2 first, after turn-navigation step 6 (#1769) merges, since
  both edit `tools-and-file-changes.md` and #1769 creates
  `transcript-turn-navigation.md`. Step 3 needs step 2. Step 4 needs step 2;
  step 5 needs step 4. Step 3 may run beside steps 4 and 5.
- **turn-navigation coordination.** Its steps 7 (pinch) and 8 (sticky prompt)
  edit `session_detail_message_list.dart` in the gesture and list-builder
  code; this plan edits only the `_kWorkingRowId` branch of `_buildRow` and
  `_workingRow`. Both plans append to `app_en.arb`. Rebase on whichever lands
  first; the conflicts are textual. If turn-navigation step 9 (desktop index)
  shows turn durations, it uses `TranscriptDurationFormatter.format` when step 4
  has landed; if step 9 lands first, step 4 moves it onto the formatter.
  turn-navigation step 10 reconciles its own document with whatever of steps
  2, 4 and 5 has merged by then.
- **Per-step evidence** in `steps/step-NN.md`, written by that step's PR.
- **Visuals.** Steps 2, 4 and 5 show before and after screenshots on phone and
  desktop from fixture sessions, plus a short recording of a ticking timer in
  step 4 and the Working-to-sub-agent handover in step 5.
- **Architecture implementation review** for steps 3 (wire and plugin
  interface removal), 4 (new builder, sealed type and widgets) and 5.
- **Checks.** `dart analyze --fatal-infos` per touched package, with the
  pinned Flutter 3.47.5 first on `PATH`; `dart test` for bridge packages and
  `module_core`, `flutter test` for `module_app_ui` and the shells.

## Steps

**Step 1 — this plan.**

**Step 2 — "N steps" and the #1738 revert.** [Architecture 1](#1-group-summary-step-2).
Verify:

- builder tests: every thinking block and tool call counts, running steps do
  not, and a lone finished step gives a summary of 1;
- widget tests: "1 step" for a lone finished step, the count rolls when a live
  row folds in, no failed segment, and a failed step is still red in the
  opened panel;
- analyze `module_core`, `module_app_ui`, `client/app`, `client/desktop`.

**Step 3 — remove the tool kind.** [Architecture 2](#2-tool-kind-removal-step-3).
Verify each plugin's tests, `bridge/app` mapping tests and the shared model
tests, and that Pi still emits edit diffs (its `pi_tool_tracker` tests);
analyze every touched package. No user-visible change.

**Step 4 — duration format, ticking time and "Working…".**
[Architecture 3](#3-duration-format-ticking-time-and-working-step-4). Verify:

- formatter tests at 0s, 59s, 60s, 3599s, 3600s and 3905s, and a negative
  input;
- ticker tests with a fake clock: first tick on the next whole second, one
  rebuild per second, disposal cancels the timer;
- builder tests: `Working` with and without an opener time, a headless
  segment, and `Idle` when `isBusy` is false;
- widget tests for the folded running turn with the timed Working row under it
  and the stub unchanged;
- a live Claude session through the headless bridge: record whether the live
  prompt carries a time, in `steps/step-04.md` and the capability doc.

**Step 5 — sub-agent row.** [Architecture 4](#4-sub-agent-row-step-5). Verify:

- builder rule table: sub-agent steps alone versus an own running step,
  streaming text, a retry row, `isBusy` false, zero running children, and the
  start precedence of P4;
- the pill still counts running children through `runningChildren`;
- widget tests: spinner not sparkle, two lines, no timer when no start is
  known, and the eased handover with "Working…";
- live probes with the headless bridge for Codex and DeepSeek (and Grok): with
  the main agent idle and a sub-agent running, send a prompt and confirm the
  main agent answers before the sub-agent finishes. Record the result and
  harness versions. A failed probe triggers P9 before the PR opens.

**Step 6 — reconcile the documents.** Bring `tools-and-file-changes.md`,
`transcript-turn-navigation.md`, `session-turns.md` and
`docs/HARNESS_CAPABILITIES.md` in line with what shipped.

**Step 7 — verify and retire.** Run L3 over the recorded matrix, record the
result in `steps/step-07.md`, record phase 2's detailed steps as a new plan
(or an update of this one, reopened under the same slug), and move this plan
to `.plan/completed/`.

## Later Phases (rough intent only)

- **Bridge prompt time.** The bridge stamps `MessageUser.time.created` when a
  plugin sends none (Grok and the other ACP harnesses; Claude live if step 4
  finds it null), and a re-import keeps the stamp by message id. Owner:
  `ChatHistoryService` (the history single writer), persisted through
  `ChatHistoryRepository`; the orchestrator only passes the stamped message
  along. Why: "Working…" then ticks on every harness.
- **Step times on the wire.** An optional `time {start?, end?}` on the tool,
  reasoning and sub-agent parts, in `sesori_shared` and the plugin interface,
  with dated COMPATIBILITY comments: an older app ignores it; an older bridge
  omits it and the app shows no step or group times, only "N steps". The
  bridge stamps `end` the first time it sees a part finish without one, and a
  re-import (`replaceSessionMessages`) carries stamped times by part id. Owner:
  `ChatHistoryService`, persisted through `ChatHistoryRepository`; the
  orchestrator only passes the stamped part along. Constraint: the unawaited
  capture path in `Orchestrator._captureAndShapePart` builds the live event
  from the shared part before the write lands, so the service must apply the
  stamp synchronously before the event is built, keeping the live event and the
  stored part equal. Why: every harness gets end times, the base for inferred
  starts (D6).
- **Plugin times (about 3–4 PRs, all harnesses).** Codex: item times onto the
  parts, and the history end from the output record. OpenCode: reasoning and
  tool state `time` (v1, and v2 once active). Claude: per-block and
  tool-result timestamps, live and in history. Pi: the tool end from
  `toolResult`, and history entry times. DeepSeek: `messageCreatedAt` as the
  start. Grok: probe `updates.jsonl` timestamps, else bridge stamps only. The
  other ACP harnesses: bridge stamps only. Why: real starts where they exist
  (D6), recorded per harness in the capability doc.
- **Running-step timers, group times and per-step times (client).** The
  inferred-start rule; a timer on the running step row; "N steps · time" that
  holds still while a step runs (D3); each step's time in an opened group
  (D10); the sub-agent row's start from its step (P4). Why: D3, D5, D6, D10.
- **Compaction running row.** A backend-neutral running compaction on the
  wire, replacing Codex's and Pi's "compact" tool part; OpenCode's early row
  fixed and its start mapped; DeepSeek's `compaction_started` mapped; Claude's
  `system/status` "compacting" probed first; the other ACP harnesses recorded
  as unsupported. Note the wire rule: `MessagePart` has no fallback union, so
  this must extend an existing part type (for example a status on
  `compaction`), never add a new one. Why: D5.

## Open Questions

None blocking. Step 4 answers whether Claude live prompts carry a time; step 5
answers the Codex and DeepSeek probes.

## Plan Review Record

**`architecture-plan-review`, 2026-09-26: rejected** with six concrete,
non-vague findings. D1–D10 were not reviewed. Layering, the display-only
timer, harness neutrality, the step order, the clean `ToolKind` removal and the
phase-2 wire shape passed. All six findings were applied directly, and the
reviewer stated the plan needs no re-review once they are:

1. Step 3 would have broken Pi's edit-diff emission, which reads the kind
   mapper. Pi now keeps a private edit predicate, and step 3 verifies diffs.
2. The "running child" rule would have had two owners. P10 moves it into
   `module_core` for both the pill and the builder.
3. The builder's inputs were unstated. P2 now gives the full signature,
   including `messages` for P4 and `isBusy` from the shell.
4. Naming: `TranscriptActivityBuilder` and `TranscriptDurationFormatter`.
5. The phase-2 stamps now belong to `ChatHistoryService`, not the
   orchestrator, and must be applied synchronously before the live event is
   built.
6. P9 now updates and re-reviews the plan instead of pointing at an unnamed
   capability seam.

This revised version was not reviewed again.
