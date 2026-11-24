# Session wake-ups and scheduled commands

Read against `origin/main` at `db631ee62d` (2026-11-23). Product version
1.16.0. Owner decisions are listed at the end.

## Goal

- **Wake-ups.** Through the Sesori MCP, a session asks Sesori to send it a
  prompt later, either once ("in 20 minutes, check the PR comments") or on
  repeat ("every 30 minutes", "daily at 9"). A wake-up needs no approval. A
  recurring one repeats until the agent calls `cancel_wakeup` or the user
  cancels it in the app. The agent never re-arms one. Wake-ups survive a
  bridge restart, and the user sees and can cancel each one.
- **Commands.** A wake-up or a scheduled task can carry a shell command. The
  bridge runs it when the wake-up or task fires and puts the result in the
  prompt.
- **Armed sessions.** The session list shows which sessions will be woken
  again (a pending wake-up, or a same-session task that will continue there),
  and when.

## Current behaviour this builds on

- **Tools.** `bridge/app/lib/src/routing/sesori_mcp/`: the `SesoriMcpTool`
  enum, `SesoriMcpRequestDispatcher` and `SesoriMcpResultFormatter`. The bearer
  token resolves to a `SesoriMcpCaller(sessionId)`.
- **Scheduled tasks cannot target the calling session.**
  `TaskRunMode.sameSession` continues `scheduled_tasks.targetSessionId`, which
  is null until the task's first run creates a new session. On an archived
  target, `ScheduledTaskRunService` starts a fresh session. It also overrides
  the session's approval mode, skips while busy, and marks the session as a
  task run. Each of those is wrong for a wake-up in the user's own session.
- **Delivery.** `SessionNoticeService.deliver` already delivers into a
  session:
  - It skips archived and deleted sessions.
  - It waits for quiet, or steers when the plugin steers and the session is
    not a task run.
  - It sends on the session lane with the session's prompt defaults, marked
    `PromptStampNotice`.
  - Its text comes from `buildSessionNotice` (`sesori_bridge_foundation`):
    `[SESORI NOTICE]`, then the user's line, then `[FOR THE AGENT]` and the
    guidance.
  - The app shows it as a "Sesori Automation" row.
  - It keeps nothing across a restart. It returns `void`.
- **Agent approvals.** `ScheduledTaskAgentService.propose*` adds a
  `ScheduledTaskAgentChange` to the in-memory `AgentApprovalRepository`, which
  the user sees as the existing permission card and push.
  `ReplyToPermissionHandler` sends the reply to
  `ScheduledTaskAgentService.settle`, which applies the change and sends a
  notice. YOLO never answers these. `PermissionAutoApprovalService.isYolo`
  gives a session's effective approve-everything state.
- **Durable timer precedent.** Quota auto-continuation:
  - Bridge: `session_continuation` (cascade),
    `SessionContinuationService.runDue` and a 30 s timer listener.
  - Wire: `Session.autoContinuation`, published through
    `SessionMutationDispatcher.continuationUpdated`.
  - Client: `SessionAutoContinuationService` → `SessionDetailCubit` →
    `SessionAutoContinuationChip`, plus the row mark
    `SessionScheduledResume`.
- **Schedule math.** `ScheduledTaskOccurrenceCalculator` handles the
  `TaskSchedule` kinds in an IANA zone across daylight-saving changes.
- **Processes.** `StreamingProcessRunner` and `ProcessRunner` in
  `foundation/` are used only from `api/` classes (`GitCliApi`,
  `DefaultEditorApi`).
- **Files.** `PromptUploadRepository` stores files as
  `<root>/<sessionId>/<date>-<random>/<name>`, readable by the user only, under
  `~/.sesori/` roots. `SessionDeletionService` deletes a session's folders.
  `deleteFileFoldersDatedBefore` sweeps by age.
- **Task mark.** The session row's mark is `_taskMark` in
  `client/module_app_ui/lib/src/features/session_list/session_tile.dart`. It is
  fed by `Session.scheduledTask` (`SessionScheduledTaskMark`: task id, name,
  kind) and shows a repeat or clock glyph with the task name.
- **Harness parity.** Tools are listed dynamically, so new tools need no
  plugin code:
  - Supported: Claude Code, Codex, Pi, Oh My Pi, Grok and GitHub Copilot.
  - Off until verified: Antigravity, Hermes and Cursor.
  - No seam: DeepSeek and OpenCode.

  Delivery is a normal bridge prompt, so it works everywhere.
- **Claude Code's native `ScheduleWakeup`.** It lives only as long as the
  resident process. It reads as `queued` readiness, is lost on restart, and is
  invisible to the app.

## Design

### Tool surface

There are three new tools. The server instructions gain one sentence: wake-ups
come back as a message, and this is the timer to use instead of a harness
timer, because the user can see and cancel it.

**`schedule_wakeup`** (not read-only) takes these arguments:

- `label`: required, up to 100 characters. The user sees it.
- `prompt`: required.
- `when`: one of the kinds below.
- `time_zone`: an IANA zone, defaulting to the bridge computer's zone. It
  applies to the wall-clock kinds.
- `command`: optional.

| `when.kind` | Fields | Meaning |
|---|---|---|
| `in` | `minutes` (1–10080) | Once, that many minutes from now. |
| `every` | `minutes` (1–10080) | Repeats at that real interval; the first fire is one interval from now. |
| `daily` | `time` (`HH:MM`) | Repeats every day at that wall-clock time. |
| `weekdays` | `time` (`HH:MM`) | Repeats Monday to Friday at that time. |
| `weekly` | `days`, `time` | Repeats on the chosen days at that time. |

The result names the wake-up's id and next time, and ends with "End your turn
now; don't wait or poll." A repeating wake-up adds "It repeats until you call
cancel_wakeup." A command wake-up that needs Allow returns the approval text
instead (see "Approval").

**`list_wakeups`** (read-only) returns this session's wake-ups: id, label,
next time, repeat description, and whether it runs a command.

**`cancel_wakeup(wakeup_id)`** cancels one of this session's wake-ups.

Rules shared with the existing tools:

- Strict-schema providers fill fields they leave out with empty strings. The
  existing `_requiredText` and `_optionalText` rules apply.
- There is no cap on pending wake-ups, because the owner rules out capping
  non-blocking requests.

**Why this recurrence shape:**

- Minutes alone can't say "daily at 9" honestly: a 1440-minute interval drifts
  an hour at each daylight-saving change.
- The task kinds alone can't say "every 30 minutes": `everyHours` starts at 1
  hour.
- `once` and `everyHours` are left out, because `in` and `every` cover them.
- Recurrence ships with one-shots, because the calendar math already exists.

### Bridge classes

| Layer | Class | Owns |
|---|---|---|
| `api/database/` | `SessionWakeUpsTable`, `SessionWakeUpDao` | Rows. |
| `repositories/` | `SessionWakeUpRepository` | Maps a row to `StoredSessionWakeUp` (in `repositories/models/`). The record holds a sealed `WakeUpSchedule` (`once(dueAt)`, `every(minutes)`, `calendar(TaskSchedule, timeZone)`) and a `WakeUpCommand?` (`command`, `approval`: `allowed` or `byMode`). |
| `services/` | `SessionWakeUpService` | Schedules, lists, cancels and fires wake-ups, and applies command approvals. |
| `listeners/` | `SessionWakeUpTimerListener` | Runs every 30 s and once at start, calling `runDue`. |
| `routing/` | `CancelSessionWakeUpHandler` | `POST /session/wake-up/cancel`. Its request model lives in `sesori_shared`. |

`SessionWakeUpService` depends on:

- `SessionWakeUpRepository`;
- `SessionRepository`, for the family root and the working directory;
- `ScheduledTaskOccurrenceCalculator`;
- `SessionNoticeService`;
- `PermissionAutoApprovalService`;
- `AgentApprovalRepository` and the approval description builder;
- `ScheduledCommandService`;
- `SessionMutationDispatcher`, through a new `wakeUpsUpdated` that matches
  `continuationUpdated`;
- `Clock`.

It never depends on `ScheduledTaskAgentService`.

Table `session_wake_ups` (schema 31 → 32):

| Column | Type |
|---|---|
| `id` | Text, primary key. |
| `sessionId` | Foreign key to `sessions_table`, `onDelete: cascade`. |
| `label` | Text. |
| `prompt` | Text. |
| `command` | Text, nullable. |
| `commandApproval` | Enum, nullable. Null exactly when `command` is; the repository maps the pair to one `WakeUpCommand?`. |
| `scheduleJson` | Text. |
| `nextDueAt` | UTC ms, indexed. |
| `createdAt` | UTC ms. |

A row exists only while its wake-up is pending or repeating. It has no status
column.

The wake-up separately gets a new table rather than a `scheduled_tasks` run
mode. A wake-up has none of a task's definition, history, approval or
Scheduled-page row. Putting it in `scheduled_tasks` would add nullable
coordination fields and reverse three same-session rules.

### Firing and delivery

- **Target.** The caller's root session, resolved once at scheduling with
  `resolveSessionFamily`, as pages are.
- **`runDue`.** It reads rows with `nextDueAt <= now` and skips ids in flight.
  The in-flight set is in memory; a restart empties it. For each due row:
  1. Advance the row. A repeating row moves `nextDueAt` to the first
     occurrence after now, so missed occurrences never pile up. A one-shot
     keeps its row.
  2. Run the command, if any, through `ScheduledCommandService`, off the lane.
  3. Deliver through `SessionNoticeService.deliver`, unawaited. The user's
     line is `Wake-up: <label>`. The guidance says when the agent asked, the
     due time, how late it is if the bridge was off, and whether it repeats,
     then gives the prompt and the command result.
- **`SessionNoticeService.deliver` changes.** All callers are updated in
  lockstep:
  - It returns a sealed outcome: `sent`, `skippedInactive`, `claimLost` or
    `dropped`.
  - Timing becomes a required public enum, `SessionNoticeTiming { derived,
    afterTurn }`. Wake-ups pass `afterTurn`, so on every harness they never
    cut into a turn.
  - A required named `claim`, typed `Future<bool> Function()?`, runs only
    inside the lane body, right before the send. For a one-shot it deletes the
    row and returns whether the row existed. For a repeating wake-up it checks
    that the row still exists. A cancel that lands while delivery waits
    therefore wins. Existing callers pass null.

How each situation is handled:

| Situation | Behaviour |
|---|---|
| Busy, awaiting the user, or a native Claude wake-up is pending | Waits for the turn to end. |
| A repeating wake-up's next occurrence arrives while the previous one is still in flight | That occurrence is skipped. |
| Archived session (`skippedInactive`) | `runDue` deletes the row, whether one-shot or repeating. If the session is unarchived before the wake-up fires, the wake-up stays. |
| Deleted session | The cascade removes the row. |
| Bridge restart | The row survives until its claim, so a waiting wake-up fires again. A due time the bridge missed fires on return and states how late it is. A crash between the claim and the send loses that one delivery: the tasks' "lose, never duplicate" rule. |
| Harness unavailable (`dropped`) | Logged with the session id. A one-shot is removed. A repeating one tries again at its next time. |

### Commands

- **Layer 0.** Reuse `StreamingProcessRunner` (spawn, timeout, kill).
- **Layer 1: `api/shell_command_api.dart`, `ShellCommandApi`.** A sealed class
  with a `forPlatform` factory and private POSIX and Windows implementations
  in the same file, like `DefaultEditorApi`:
  - POSIX runs `$SHELL -lc <command>`, falling back to `/bin/sh -lc`. A login
    shell gives a launchd-started desktop bridge the user's `PATH`.
  - Windows runs `cmd.exe /d /s /c`.
  - It streams stdout and stderr to the two paths it is given, kills the
    command at the 10-minute timeout, and returns a typed result. The outcome
    is `exited(code)`, `timedOut` or `couldNotStart(error)`. Per stream, the
    result also carries the word count and the last 20 lines.
- **Layer 2: `repositories/scheduled_command_repository.dart`.** It combines
  `ShellCommandApi` with a fourth `PromptUploadRepository` rooted at the new
  `sesoriCommandOutputDirectory()`
  (`~/.sesori/command-output/<key>/<YYYY-MM-DD>-<random>/{stdout,stderr}.txt`).
  - `PromptUploadRepository` gains a folder-reservation method, because
    `save()` takes bytes.
  - `<key>` is the target session id. A new-session task run has no session
    yet, so it uses `task-<taskId>`.
  - The files are user-only, outside every project, and survive a reboot,
    unlike `/tmp`.
- **Layer 3: `services/scheduled_command_service.dart`,
  `ScheduledCommandService`.** It is the one owner for both triggers. It runs
  the command, has the pure `ScheduledCommandResultFormatter` build the
  agent-facing block, and owns its root's 7-day age sweep, at startup and
  after each run. `SessionDeletionService` deletes a session's folder with the
  other roots.
- **Result block.** It starts with the exit code: `command exited 0`,
  `timed out after 10 minutes` or `could not start: …`. Stdout and stderr each
  get their own section:
  - a stream of 500 words or fewer goes inline in a fence;
  - a larger stream becomes `stdout 32,131 words; full output at <path>` plus
    its last 20 lines;
  - an empty stream reads `stdout: empty`.
- **Working directory.**
  - A wake-up runs in the target session's directory: its worktree if it has
    one, otherwise the project.
  - A same-session task runs in its target's directory.
  - A new-session task runs in the project path, because its worktree doesn't
    exist yet.
- **Concurrency.** A command never runs on the session lane, nor inside the
  task fire lock.
- **Known gap.** A kill may leave grandchild processes running. If a real
  command hits this, move to process-group kill.

### Approval of command wake-ups

- **The approval union is renamed now.** It becomes the sealed
  `AgentApprovalChange` with two families:
  - the existing `ScheduledTaskAgentChange`;
  - a new `WakeUpCommandChange`, with `ScheduleCommandWakeUp` and
    `ConfirmByModeCommand`.

  A sibling `WakeUpCommandDescriptionBuilder` writes the card text: the
  command first, then the working directory, the schedule and the label.
- **Approve-everything session.** If `isYolo(target)` holds at scheduling, the
  wake-up is stored at once with `approval: byMode`.
- **Any other mode.** `SessionWakeUpService` adds a `ScheduleCommandWakeUp`
  straight to `AgentApprovalRepository` and returns the existing
  `_appliesOnAllow` text, with "because it runs a command".
- **Settling.** `settle` stays the single entry point for replies. It passes a
  `WakeUpCommandChange` to `SessionWakeUpService.applyCommandApproval`, so
  dependencies run one way: from the task agent service to the wake-up
  service.
  - On Allow, the wake-up is stored with `approval: allowed`, and its first due
    time counts from the moment of Allow.
  - On Reject, nothing is stored.
  - The session hears the outcome through the existing notice.
  - YOLO never answers these requests.
  - A restart drops a pending request, as it does for every agent approval.
- **A session that left approve-everything.** A command stored as `byMode`
  never bypasses the session's current mode:
  - At fire time, if `isYolo` no longer holds, the service raises a
    `ConfirmByModeCommand` card before the command runs, and the wake-up
    stays in flight.
  - The in-flight entry is cleared only by `applyCommandApproval` or a
    restart. After a restart the row fires again and asks again.
  - On Allow, the command runs, the wake-up is delivered, and the row is
    upgraded to `allowed`.
  - On Reject, the wake-up is cancelled and the session is told.
  - An `allowed` command never asks again.
- **Wake-ups without a command** never need Allow.

### Scheduled-task commands

- **Where the field lives.** `ScheduledTask.command: String?` sits on the
  task, outside `ScheduledTaskDefinition`, as the bridge-owned `enabled`
  already is. The app sends the definition whole on create and update, so an
  older public app editing a task would wipe a command stored inside it.
  - Storage: a nullable `scheduled_tasks.command` column, in the same schema
    bump if the steps land together, otherwise the next one.
  - An older app ignores the field.
- **Agent tools.**
  - `create_task` gains `command`, and `CreateTaskChange` gains
    `String? command`.
  - `update_task` gains `command` and `remove_command: bool`, because an empty
    string already means "left out". The dispatcher parses them into a sealed
    `TaskCommandEdit` (`unchanged`, `set(String)`, `remove`), and
    `UpdateTaskChange` carries it. A command together with `remove_command`
    is rejected at the boundary.
  - `StoredTaskChange.before` also captures the command, so Allow's staleness
    check covers it.
  - The request text shows the command first, as "Approve everything" is shown
    today.
- **The run.** `ScheduledTaskRunService` writes the run row as today
  (`started`, session null) before the command. It then runs the command and
  the send in a future it tracks in memory, next to `_promptSentAt`.
  - `_isPreviousRunActive` counts a running command as active.
  - `dispose()` awaits the tracked futures.
  - A crash during the command leaves the same `started` row with a null
    session that a crash before the send leaves today.
  - Run now, for a task with a command, returns once the row is written and
    doesn't wait for the command. The app already gets the session through
    `changes`; step 4 checks that the run-now caller handles a null session.
- **The result** reaches the run's prompt as a hidden bridge note, with the
  same `[SYSTEM CONTEXT — IMPORTANT]` marker and `stripSystemContext` as the
  run note.
- **Slash-command tasks** refuse a shell command in this plan.
- **The app** shows a task's command read-only in task details.

### Wire and bridge projection

These additions to `Session` are additive:

- **`wakeUps`.** A list of `SessionWakeUp`, each with `id`, `nextDueAt` (ms),
  `label`, `repeats` and `runsCommand`. It defaults to an empty list:
  `// COMPATIBILITY 2026-11-23 (v1.16.0): bridges before wake-ups omit the list, which honestly means none. Remove the default once the minimum supported bridge always sends it.`
- **`arming`.** A sealed `SessionArming` with three variants:
  - `unreported()`, the default for older bridges, which show today's mark;
  - `notArmed()`;
  - `armed(name, nextAt, origin)`, where `origin` is `wakeUp` or `task`.

  It needs its own COMPATIBILITY comment: older bridges omit it, so the app
  keeps today's task mark.
  - **When a session is armed.** It has a pending wake-up, or it is the
    non-archived target of an enabled same-session task with a next due time.
  - **Which one is shown.** `armed` carries the earliest of these: a
    wake-up's label or the task's name, and its time.

`SessionViewService` gains `SessionWakeUpRepository` and the task target
lookup. Publishing a session (through `wakeUpsUpdated`) happens on:

- a wake-up being scheduled, cancelled, fired or advanced;
- a task change that moves a target's arming: enable or pause, edit, fire,
  retarget, or delete.

### App

- **`module_core`.**
  - The chain is `SessionApi.cancelWakeUp` → `SessionRepository.cancelWakeUp`
    → `SessionWakeUpService` (`module_core/lib/src/services/`) →
    `SessionDetailCubit` state and action.
  - A pure `SessionScheduledMarkCalculator` decides the row mark and the
    chip's next time, as a sealed `SessionScheduledMark`:
    - `resumes(at)`, from auto-continuation;
    - `armed(name, at)`;
    - `fromTask(name)`;
    - `legacyTask(mark)`, today's mark, for `unreported`;
    - none.

    When continuation and arming are both present, the earlier time wins. The
    session-list state and the `SessionDetailCubit` state carry the result.
- **`module_app_ui` (owner picks).**
  - **Session row.** The widget only renders the calculated mark:
    - **Armed:** the accent-coloured repeat glyph and `<task or label> · next
      09:00`, with the date when it is not today. This replaces the earlier
      "Wakes 14:20" mark.
    - **Started by a task but not armed** (new-session runs, old targets,
      paused tasks): plain grey `from <task>`, with no glyph.
    - **Older bridge:** today's `_taskMark`.
  - **Composer.** While any wake-up exists, a clock chip shows the next time,
    built like `SessionAutoContinuationChip`. Its menu lists each wake-up's
    time and label, with a repeat mark when it repeats and a terminal mark
    when it runs a command, plus Cancel. Cancel works for repeating wake-ups
    too.
  - **Task details.** The command is shown read-only.
  - **Motion.** The chip sits in an existing row and fades in place, so
    nothing above the transcript moves. A mark change cross-fades in place,
    as row details already do.
- **Shells.** Phone and desktop share the widgets.

## Steps

Titles follow `<emoji> [session-wakeups] … [step x/8]`.

1. 🌱 **Raise the plan.**
2. 🚧 **Bridge wake-ups, one-shot and repeating.**
   - Bridge work: the table and DAO, the repository and its models,
     `SessionWakeUpService`, the listener, and the `deliver` outcome, timing
     and claim.
   - Agent surface: the three tools without `command`, the formatter lines
     and the instructions.
   - Docs: `HARNESS_CAPABILITIES.md` and `regression/sesori-mcp.md`.
   - Tests: validation and caller scoping; due selection, advancing and
     in-flight skips; a cancel racing a waiting delivery; archived, deleted,
     restart and late cases; zone cases through the calculator.
3. 🚧 **Wake-up commands.**
   - The command classes: `ShellCommandApi`, `ScheduledCommandRepository`
     (with folder reservation), `ScheduledCommandService` and its formatter.
   - Output files: the command-output root, its sweep and its deletion.
   - The `command` argument on `schedule_wakeup`.
   - The `AgentApprovalChange` rename, `WakeUpCommandChange` and its builder,
     `applyCommandApproval`, and the fire-time confirmation.
   - Tests: the inline and file thresholds per stream; timeout and kill;
     can't start; the YOLO versus ask split; Allow and Reject; leaving YOLO;
     the upgrade.
4. ⚙️ **Scheduled-task commands.**
   - Bridge: the column, `ScheduledTask.command`, `command`, `remove_command`
     and `TaskCommandEdit`, the staleness capture, the run-service command
     phase and Run now, the hidden note, and the slash-command refusal.
   - App: the read-only command in task details.
5. ⚙️ **Bridge projection.**
   - Wire: `Session.wakeUps` and `Session.arming`.
   - Bridge: `SessionViewService`, `wakeUpsUpdated`, publishing on task
     arming changes, and the cancel route and handler.
6. ⚙️ **App.**
   - `module_core`: the cancel chain, `SessionScheduledMarkCalculator`, and
     the cubit and list state.
   - `module_app_ui`: the composer chip and menu, and the row mark (armed,
     `from <task>`, legacy).
   - Also l10n, widget tests, and before/after visuals.
7. 🌱 **Reconcile regression docs.** `sesori-mcp.md`, `scheduled-tasks.md`, the
   session list, and session detail.
8. 🌿 **Verify and retire.** Run the matrix below, record it, and move the
   plan to `completed/`.

Dependencies:

- Steps 3 and 5 depend on step 2.
- Step 4 depends on step 3.
- Step 6 depends on step 5.
- Step 5 can run alongside steps 3 and 4.

Each step stays under about 1,500 lines, and Drift output is reported
separately.

## Verification

- **L2.** The automated tests named in each step.
- **L3, on each injected harness.** Run on Claude Code, Codex, Pi, Oh My Pi,
  Grok and Copilot, through the local test proxy:
  - A one-shot set 1–2 minutes ahead arrives as `Wake-up: <label>`, followed
    by an agent turn.
  - `every 2` fires twice, then `cancel_wakeup` stops it.
- **L3, once each:**
  - A wake-up due while busy waits for the turn on Claude Code (which steers)
    and on Grok (which doesn't).
  - A restart with a one-shot pending and a repeating one active.
  - Archiving a session with a repeating wake-up.
  - In YOLO, a command wake-up shows no card. In ask mode it shows the card,
    and Allow schedules it.
  - A `byMode` wake-up asks at fire time after the session leaves YOLO.
  - Inline output, and file output with its tail; the agent reads the file.
  - A task with a command.
  - The timeout, via a fixture `sleep`.
- **App, iOS simulator only (headless):**
  - the chip, the menu marks and Cancel on a repeating wake-up;
  - the armed mark for a wake-up and for a same-session task;
  - `from <task>` on a paused task's session;
  - the legacy mark against an older bridge fixture;
  - the read-only task command.
- **Material failure signals:**
  - A wake-up fires twice for one occurrence, fires into another session or an
    archived one, cuts into a turn, or fires after a cancel.
  - A command runs before Allow outside YOLO, or runs as `byMode` without a
    card after its session leaves YOLO. YOLO answers a command request.
  - Output lands inside a project or in `/tmp`, or outlives its session or the
    7-day sweep.
  - An app edit drops a task's command.
  - An armed mark stays after its wake-up or task stops arming the session.

## Cleanup assessment

Nothing becomes obsolete:

- `SessionNoticeService` keeps its in-memory rule for its own notices.
- `ProcessRunner` keeps its short, buffered callers.
- The plain `_taskMark` stays as the fallback for older bridges. Its legacy
  path goes once the minimum supported bridge reports arming.

There are no analytics: the authoritative outcome happens on the bridge, which
has no product-analytics path.

## Risks

- **The agent doesn't end its turn.** The tool result asks it to. The wake-up
  waits for quiet, so the cost is only a delay.
- **No approval for wake-ups without a command.** Such a wake-up sends an
  agent-written prompt into the agent's own session, under that session's
  approval mode. That is no more reach than the agent has during its own turn.
- **Commands run outside the harness permission check.** The approval rules
  above guard this, including the check at fire time. The chip marks every
  wake-up that runs a command.

## Architecture plan review

**Round 1 (2026-11-23, `architecture-plan-review`, opus sub-agent): rejected.**
It found six blocking and four minor issues. Every finding was valid and was
applied without a re-review:

1. A new runner in `foundation/` that services called directly. Fix:
   `StreamingProcessRunner` → `ShellCommandApi` (api) →
   `ScheduledCommandRepository` → `ScheduledCommandService`.
2. No single owner of the command pipeline. Fix: `ScheduledCommandService`
   with a pure formatter owns it, including its sweep.
3. A cycle risk in settling approvals, and an undecided rename. Fix:
   `AgentApprovalChange`, with wake-up requests going straight to
   `AgentApprovalRepository`, and `settle` → `applyCommandApproval` in one
   direction.
4. The run-row lifecycle during a task command. Fix: the row is written as
   today, an in-memory command phase counts as active, `dispose` awaits it,
   and Run now returns early.
5. Wake-up classes and their dependencies were not named. Fix: the bridge
   classes table.
6. The row-mark decision sat in the UI. Fix: `SessionScheduledMarkCalculator`
   in `module_core`.
7. The client chain was implicit. Fix: it is named.
8. `deliver` returned void. Fix: a sealed outcome, a public timing enum, and a
   lane-only claim.
9. The task command edit was a tri-state. Fix: `TaskCommandEdit`, plus the
   staleness capture.
10. Step 5 needed step 4's field. Fix: the task-command display moved into
    step 4.

The armed-sessions mark was added after the review. It follows the reviewed
patterns: an additive wire field with a dated default, projection in
`SessionViewService`, and a pure calculator in `module_core`.

## Owner decisions (2026-11-23)

- **Q1.** Wake-ups need no approval, recurring ones included. A recurring
  wake-up repeats until the agent cancels it, and the agent never re-arms it.
- **Q3.** The composer clock chip, plus a mark on the session row.
- **Q4.** App visibility is part of this plan.
- **Q5.** The user's line reads "Wake-up: <label>".
- **Commands.** Wake-ups and tasks can carry a command:
  - The result goes inline when it is 500 words or fewer, otherwise to a file
    plus its last 20 lines.
  - The exit code is reported, with stdout and stderr kept apart.
  - The command runs in the session's project, with a 10-minute timeout.
  - Files are not kept in `/tmp`.
- **Command approval.** No Allow in YOLO sessions, Allow in every other mode,
  through the existing card and approval path.
- **Q6 (B, lightly).** A command approved only by mode asks again at fire time
  once its session has left YOLO.
- **Q7 (A).** App Cancel works for repeating wake-ups too.
- **Armed sessions.**
  - Armed: an accent repeat icon and `<task or label> · next 09:00`.
  - Started by a task but not armed: grey `from <task>` with no icon.
  - One shared mark for tasks and wake-ups.
  - An older bridge keeps today's mark.

**Decided without asking (open to veto):**

- the recurrence shape;
- the root session as target;
- waiting for the turn to end on every harness;
- late fire after downtime;
- skipping an occurrence that is still in flight;
- archiving ends a wake-up;
- a separate table;
- the login shell;
- the working directory in each case;
- `~/.sesori/command-output`, kept 7 days and removed with its session;
- the task command kept outside the definition;
- no command on slash-command tasks;
- the first due time counts from Allow;
- no analytics.

## Later phases (rough intent only)

- **App-created wake-ups and app editing of a task's command.** Why: humans and
  agents should use the same API.
- **Commands on slash-command tasks**, if a real need shows up.
- **OpenCode and DeepSeek** once they have a per-session seam, and
  **Antigravity, Hermes and Cursor** once their injection is verified. Why:
  parity.
