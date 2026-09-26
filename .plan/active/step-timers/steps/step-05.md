# Step 5 — sub-agent row

## Shipped

- `module_core`:
  - `TranscriptActivityBuilder` gains `TranscriptActivitySubAgents({count,
    sinceMs})` and the inputs it reads (`messages`, `children`,
    `childStatuses`). The rule is P3: busy, no retry row, no streaming text, no
    running step other than a sub-agent step, and at least one running child.
    It is checked before `Working`, whose rule is unchanged.
  - `sinceMs` follows P4: per running child, the earliest `time.created` of a
    message holding a sub-agent step linked to it, else the child's own
    `time.created`; the earliest known one wins, and none gives no timer.
  - `runningChildren` in `session_detail_resolvers.dart` is the one owner of
    "running child" (busy or retrying). The pill's private `_isRunning` is
    gone; the pill and the builder both call it.
- `module_app_ui`:
  - `TranscriptSubAgentsRow({count, sinceMs})` in `transcript_live_row.dart`:
    a `PregoActivityIndicator` in the sparkle-sized slot, the first line in
    the secondary text colour with no shimmer (count, then " · " and a ticking
    `TranscriptElapsedTime` when a start is known), and the second line in the
    tertiary colour. Both lines always show, so the height never changes with
    the count or the time. One semantic label carries both lines and the time
    as of the build.
  - `SessionDetailMessageList` renders it in the `_kWorkingRowId` presence
    column under its own key, so the handover with "Working…" eases: the new
    row grows in while "Working…" folds away beneath it.
- Strings: `transcriptSubAgentsRunning` (plural) and
  `transcriptSubAgentsKeepChatting`; l10n regenerated.
- Docs: `tools-and-file-changes.md` (the row, its rule and copy, a failure
  signal, the L1 and L3 rows, sources); `HARNESS_CAPABILITIES.md` "Live
  timers" gains the sub-agent start and "prompt while sub-agents run" columns.

## Deviations

- P10 named the helper `runningChildCount`. It returns the running children
  (`runningChildren`) instead, because the pill also splits its list into
  running and idle and the builder needs each running child's start. The count
  is its length. PLAN and TRACKER now use the new name.

## Architecture review

`architecture-implementation-review` of this branch against `origin/main`:
approved, no blocking findings. Its one note, the helper's old name in
PLAN.md, is applied.

## Keep-chatting probes (P9)

No probe contradicted the second line, so no capability was added.

- **Codex: verified live.** codex-cli 0.156.1, `codex app-server` driven over
  JSON-RPC (2026-09-26). The parent spawned one sub-agent told to run
  `sleep 90`, then ended its turn (`turn/completed` at 15.0 s; the child's
  turn started at 9.1 s). A second `turn/start` on the parent at 18.0 s was
  accepted at once and answered at 20.3 s, while the child still slept. Code:
  `CodexPluginImpl.sendPrompt` calls `turn/start` directly and queues nothing.
- **DeepSeek: verified by code, not probed live.** The adapter
  (`sesori-deepseek-acp`) is not installed on this machine. The September
  probe (`.plan/completed/claude-inline-subtasks/followups/deepseek-probe.md`)
  shows the parent idle while a background child runs. The DeepSeek plugin
  sets no root hold (only Grok calls `mapChildFinishedAndHoldRoot`), so `AcpPlugin` sends
  `session/prompt` at once with no `session/cancel`. A prompt that meets
  DeepSeek's own follow-up turn after a child settles is still unconfirmed;
  it stays in the step-7 L3 matrix.
- **Grok: code re-read.** While the root is idle a prompt goes out at once.
  During the wake turn after a finished sub-agent (a root hold), a new prompt
  cancels that turn (`_cancelActiveTurnForQueuedInput`) and is then answered.
  The row itself never needs a hold to show, so the line holds; the cancel is
  recorded in `HARNESS_CAPABILITIES.md`.
- Claude and OpenCode were already verified in the plan, for background
  children only. The PR review found the foreground case (below).

## Review follow-up: foreground sub-agents

The Opus review of #1787 found that a Claude foreground `Agent` call (no
`run_in_background`) also becomes a running sub-agent part, while the parent
turn waits on it, so the row would have claimed chatting.

- **Claude: verified live.** Claude CLI in stream-json with
  `--replay-user-messages`, haiku, 2026-09-26. The foreground `Agent` tool_use
  came at 4.7 s; a second prompt was written at 12.7 s; the `Agent`
  tool_result came at 23.6 s, and only then was the prompt echoed as replayed
  and answered ("PONG" at 30.6 s). A prompt sent during a foreground call
  waits for it. The plugin tells the two apart only by the tool result
  (`ClaudeToolUseResultAsyncLaunched` for a background launch), and its turn
  state already reports the difference: `mainAgentRunning` is `isTurnRunning`,
  true while the parent turn waits on the call.
- **Other harnesses.** DeepSeek's foreground children keep the parent's ACP
  turn running (the September probe), so `mainAgentRunning` holds. A Codex
  parent waiting on its sub-agent is mid-turn. OpenCode's foreground Task was
  already the parent's own step. Grok's sub-agents run while the root idles.
- **Fix, client-only and backend-neutral.** No wire or contract change: the
  existing `ActiveSession.mainAgentRunning`, which every plugin already sets
  from its own turn state, now reaches the session detail.
  `SessionDetailCubit` reads it from `SseEventTracker` into
  `SessionDetailLoaded.mainAgentRunning`, and `TranscriptActivityBuilder`
  shows the row only while it is false. While it is true the running sub-agent
  tile shows, or "Working…" between steps.
- The review's second finding: `hasActiveWork` now uses the shared
  `isChildRunning` status rule, which `runningChildren` also uses.

## Verification

- `dart analyze --fatal-infos`: `module_core`, `module_app_ui`. No issues.
- `dart test test/cubits/session_detail` (`module_core`, including the
  sub-agent rule table and start precedence in
  `transcript_activity_test.dart`, `runningChildren`, `isChildRunning`, and
  the cubit following `mainAgentRunning` in `session_detail_cubit_test.dart`):
  pass.
- `flutter test test/features/session_detail` (`module_app_ui`: the row's
  spinner, two lines, ticking time, semantics and steady height without a
  time; the eased handover with "Working…" in the message list; the pill's
  running count through `runningChildren`): pass.
- Before and after renders, phone and desktop, and a handover GIF, all from
  fixture data: `pr-media` branch, `step-timers/sub-agent-row/`.
