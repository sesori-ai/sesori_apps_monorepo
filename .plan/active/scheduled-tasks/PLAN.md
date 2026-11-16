# Scheduled And Recurring Tasks

## Status

- **Date:** 2026-11-15. Code facts are from `origin/main` at `25d9a40a2f`
  (product version 1.14.0, bridge drift schema 25).
- **Design source:** three review rounds the user answered on 2026-11-14/15.
  The decisions below are final; do not reopen them.
- **Phase 1:** steps 2–11. Steps 12 and 13 are the regression-doc and
  retirement steps. The later phase (agent MCP tool) has rough intent only.
- **Q1 resolved (2026-11-15): option B.** The auto-compact quiet window
  follows each session's prompt-cache life (P10). No product question is open.

## Goal

A user sets up a task once: a prompt, where it runs, when, and how each run
behaves. The bridge runs it headlessly, once or on repeat, with every app
closed. Tasks have their own **Scheduled** page next to Archived, with
Recurring and Once headings. A task run is an ordinary session with a small
repeat or clock mark and the task's name. The user hears about a run only when
it needs them or can't start.

## User Decisions (final)

- D1. **Separation.** Automation stays out of the normal send flow. Tasks are
  set up and managed on a **Scheduled** page next to Archived (phone: Settings;
  tablet: from Settings; desktop: sidebar row under Archived and the command
  palette). Headings: Recurring, then Once. A heading is absent when it has no
  tasks. Recurring rows have an on/off switch; Once rows show when they run.
- D2. A one-off task leaves the Scheduled page after it runs. Its session keeps
  the clock mark.
- D3. **Run rows** are ordinary session-list rows with a repeat mark (recurring)
  or clock mark (once) and the task name.
- D4. **New task screen** = the new-session composer and its pickers (project,
  harness, agent, model and effort, fast mode, worktree switch) with two summary
  lines above the composer, **When** and **Each run**. Each line shows its
  current choice and opens a small sheet that slides up; nothing on the screen
  moves. Defaults are pre-filled so saving after picking only the time works.
  The button is **Save task**.
- D5. **When sheet:** presets Once, Every day, Weekdays, Weekly (chosen days),
  Every few hours (1–12); day and time fields; the missed-run choice.
- D6. **Each run sheet:** New session or Continue in the same session;
  Approvals (Ask me / Approve everything, defaulting to what new sessions use);
  Auto-compact, shown only for Continue in the same session.
- D7. **Missed runs:** per task, "Run when back" (default; one run, marked
  "ran late", never a pile-up) or "Wait for the next time".
- D8. **Overlap:** if the previous run is still going, the run is skipped and
  the history says so.
- D9. **Same-session task whose session is gone** (archived or deleted): the
  next run starts a fresh session and continues there.
- D10. **Run history:** only the last 5 finished runs are kept; older ones are
  archived automatically. Archiving skips a pinned run, a run still working or
  waiting on the user, and a run with uncommitted work (the usual cleanup
  refusal keeps that work).
- D11. **Pushes:** only when a run needs the user (question, permission) or
  can't start (with the reason). A finished run's "turn completed" push is
  suppressed.
- D12. **Runs on the bridge**, headless. Tasks belong to one computer, like its
  sessions.
- D13. **Auto-compact policy (round 3, option A):** compact right after the
  run, and before the next run only if that did not happen. The user's note,
  verbatim: "I think we need a "compact" after 25 mins idle or something like
  this. Cause a PR monitor may be active or similar which keeps the session idle
  for a bit despite not having "completed" the task. We need to think about
  edge cases here around tasks scheduled to start within this time window/etc."
- D14. Where a harness cannot compact on request, the switch still shows and a
  tap explains why. Gaps go into `docs/HARNESS_CAPABILITIES.md`.
- D15. Earlier "decided without asking" calls the user did not veto: a task
  saves prompt (text or slash command), project, harness, agent, model, effort,
  fast mode and worktree switch; no attachments in v1; with the worktree switch
  on, each new-session run gets its own worktree, a same-session task keeps
  one; editing changes future runs only; deleting a task leaves its sessions as
  ordinary sessions; a run that can't start shows as failed with the reason and
  never swaps in another model; the task name is the prompt's first line,
  editable; Run now, Pause/Resume, Edit and Delete live on the task's own page
  with its run history (ran, ran late, skipped, couldn't start); an older
  computer answers a tap with "Update this computer to schedule tasks".

## Current Behavior (origin/main `25d9a40a2f`)

### Bridge

- **Durable timer precedent.** Quota auto-continue:
  `bridge/app/lib/src/listeners/session_continuation_timer_listener.dart`
  runs `runDue()` at start (startup catch-up) and re-arms a 30 s one-shot timer
  after each pass. Policy in `services/session_continuation_service.dart`:
  per-session operation lane (`SessionOperationDispatcher`), readiness checks,
  a `consumed` marker written before sending (at most once; a crash can miss a
  run, never double-send), send through
  `SessionPromptService.sendPromptAlreadyReserved`. Storage table
  `session_continuations` with JSON outcome. No wake hook: after sleep the next
  tick compares wall-clock time, so catch-up happens within ~30 s.
- **Create path.** `POST /session/create` →
  `SessionCreationService.createSession(CreateSessionRequest)`: validates
  project and plugin (`ensurePluginRoutable`), prepares a worktree, creates the
  session and sends the first prompt or command, **records new-session
  defaults** for the harness, starts late title generation.
  `CreateSessionRequest` has no approval field.
- **Follow-up sends.** `POST /session/prompt_async` →
  `SessionPromptService.sendPrompt` on the session lane: refuses archived
  sessions, dedupes on `promptId`, cancels pending quota continuation, calls the
  plugin. Archived sessions can never be prompted again (read-only archiving).
- **Database.** `bridge/app/lib/src/api/database/database.dart`,
  `schemaVersion 25`, `stepByStep` migrations, dumps under
  `bridge/app/drift_schemas/default/`, migration tests under
  `bridge/app/test/drift/default/`. `sessions_table` has `pinned`,
  `archivedAt`, `approvalOverride` (`ask`/`yolo`/null = follow global),
  `lastActivityAt` (written on message updates and question/permission events,
  not on status changes or deltas, and coalesced away for repeated assistant
  activity on an unseen, unviewed session), `lastUserMessageAt`, worktree columns.
- **Approvals.** Global `BridgeSettings.yolo` (JSON config). Per session
  `approvalOverride` via `YoloSettingsService.setSessionOverride`;
  `PermissionAutoApprovalService.isYolo/approvePending`; the orchestrator
  auto-approves `PermissionAsked` before any push. YOLO covers permissions, not
  questions.
- **Archive/cleanup.** `SessionLifecycleService.cleanupAlreadyReserved` refuses
  without `force` when the worktree is shared or `checkWorktreeSafety` finds
  unstaged changes or commits on no branch. No automatic archiving job exists.
- **Pushes.** `push/completion_notifier.dart` debounces busy→idle with the whole
  family idle and nothing pending; `CompletionPushListener` builds and sends
  via `PushDispatcher.dispatchCompletion` and already carries abort
  suppression. Needs-you pushes go out immediately as category
  `aiInteraction`. `NotificationCategory` has an `unknown` fallback.
- **Status signals.** `PluginSessionStatus` idle/busy/retry; pending questions
  and permissions; `PushSessionStateTracker.hasPendingInteraction`.
  `getQuotaContinuationReadiness` (idle, busy, retrying, queued, awaitingInput,
  unavailable, unknown) is implemented only by Claude and Pi; others return
  `unavailable`. On Claude, background tasks keep status busy and a pending
  `ScheduleWakeup` reads idle status but `queued` readiness.
- **Compaction.** No route, interface method or capability flag. It is the
  catalog command named `compact` (`PluginCommand.compaction`), run through
  `sendCommand`: Claude native `/compact`, Codex `thread/compact/start`,
  OpenCode v1 reserved message / v2 `POST /session/:id/compact`, Pi RPC
  `compact`, Cursor maps it to `/summarize`. The ACP harnesses (Copilot,
  Hermes, OMP, Grok, DeepSeek, Antigravity) have it only if their native
  command list does; unverified. **On shared ACP, `sendCommand` cancels an
  active turn** (`cancelsActiveTurnForQueuedInput`), so compaction must only be
  sent to an idle session.
- **Wire gating.** No capabilities handshake. Unknown route → 404
  `no handler found for`, which clients treat as an older bridge; per-response
  flags with `@Default` and `COMPATIBILITY` comments for omitted fields.
- **Analytics.** The bridge emits no product analytics.
- **Time zones.** `timezone` is a dependency of `sesori_plugin_claude` only.

### Client

- **Archived.** `AppRouteDef.archivedSessions`; phone Settings row
  `settings_archived` in `module_app_ui/.../settings/widgets/bridge_settings_section.dart`;
  desktop `desktop-sidebar-archived` in `desktop/lib/core/widgets/desktop_sidebar.dart`
  and a command-palette entry in `desktop_cockpit_shell.dart`; mobile route is
  a ShellRoute in `app/lib/core/routing/app_router.dart`, desktop a plain
  GoRoute in `desktop_router.dart`.
- **New session.** `NewSessionView` (1,306 lines) reads `NewSessionCubit`
  (1,644 lines) throughout. The cubit owns harness discovery, option loading,
  remembered choices, drafts and login-required states, and submits through
  `SessionLaunchService.launch`. `PromptInput.onSend` is generic but its send
  icon is fixed. Slash commands are staged through `CommandPicker`.
- **Rows.** `SessionTile` shows a grey pin after a pinned title and the meta
  line (status, project). `SessionScheduledResume` already uses a clock plus a
  time in the time slot for quota auto-continuation.
- **Sheets/pickers.** `showPregoModal` is adaptive (sheet on touch, dialog on
  pointer). There is **no time or date picker** in the client and no IANA time
  zone source (`flutter_timezone` is absent).
- **Gating precedent.** Auto-continuation: 404/405 →
  `...UnavailableException`; UI shows an older-bridge row whose tap opens
  `showBridgeUpdateSheet`.
- **Multi-computer.** One live target computer; screens are bound to it
  through `ComputerSwitchDispatcher`. Pushes carry `bridgeId`; opening one
  switches computer first.
- **Analytics.** Closed events in
  `client/module_core/lib/src/foundation/models/product_analytics/`; example
  `SessionCreatedWithMessageEvent` fired by `SessionLaunchService` on success.
  `analytics_route_listener.dart` maps every route to an `AnalyticsScreen`.

## Planning Decisions

Engineering calls made from code evidence. P-numbers are referenced by steps.

### P1. Ownership and placement

- Tasks belong to the bridge that runs them (D12). Each bridge stores its own
  tasks in its drift database; the client shows the current computer's tasks.
  No cross-computer list in phase 1.
- Bridge (`bridge/app`): drift tables and DAO; `ScheduledTaskRepository`;
  `ScheduledTaskService` (CRUD, validation, next-run times, a change stream);
  `ScheduledTaskRunService` (firing, missed/overlap rules, history, archiving,
  and the only entry the tick calls); `ScheduledTaskCompactionService`
  (step 11, injected into the run service); `ScheduledTaskTimerListener` (the
  tick); `ScheduledTaskFailurePushListener` in `push/`; route handlers. The
  pure `ScheduledTaskOccurrenceCalculator` lives in `services/` (beside
  `project_glossary_term_calculator.dart`) and owns both occurrence math and
  the grace/missed decision.
- `ScheduledTaskRunService` dependencies, all constructor-injected:
  `ScheduledTaskRepository`, `SessionCreationService`, `SessionPromptService`,
  `SessionOperationDispatcher`, `SessionRepository` (quietness, P6),
  `SessionLifecycleService` (archiving through `updateArchiveStatus`, P8), `YoloSettingsService` /
  `PermissionAutoApprovalService`, `SessionOptionsService` (model check, not
  plugin calls), `ScheduledTaskOccurrenceCalculator`, `ScheduledTaskCompactionService`
  (step 11) and a `Clock`.
- Plugin interface: a typed `compactSession` method and a descriptor flag
  (P9). Backend specifics stay in plugins.
- Shared (`shared/sesori_shared`): wire DTOs only.
- Client: `module_core` API → repository → cubits (`ScheduledTasksCubit`,
  `ScheduledTaskDetailCubit`, `ScheduledTaskEditorCubit`); shared views in
  `module_app_ui/lib/src/features/scheduled_tasks/`; shells wire routes and
  entries; the time picker lives in `module_prego`.

### P2. Wire contract (sesori_shared)

- `ScheduledTask`: `id`, `definition`, `enabled`, `nextRunAt` (null when
  paused or done), `lastRun` (the newest run row, nullable). The user-editable
  part is one `ScheduledTaskDefinition` (`name`, `prompt`, `projectId`,
  `pluginId`, `agent`, `model`, `variant`, `fastMode`, `dedicatedWorktree`,
  `schedule`, `timeZone` (IANA name), `missedRunPolicy` (`runWhenBack`,
  `waitForNext`), `runMode`, `approvalMode` (`ask`, `approveAll`)), which the
  create and update requests carry whole (step 2).
- `ScheduledTaskPrompt` sealed: `text(text)` | `command(name, source,
  arguments?)` | `unknown` fallback. No attachments in v1, so no part list.
- `TaskSchedule` sealed: `once(localDateTime)`, `daily(time)`,
  `weekdays(time)`, `weekly(days, time)`, `everyHours(hours 1–12,
  startLocalDateTime)`, plus an `unknown` fallback union so an app older than a
  future schedule kind shows the task read-only ("Edit on a newer app") instead
  of failing to decode the list.
- `TaskRunMode` sealed: `newSession` | `sameSession(autoCompact)` | `unknown`
  fallback. Auto-compact exists only on the variant that can have it. The
  target session id is bridge state, not editable wire input.
- `ScheduledTaskRun`: `id`, `scheduledFor`, `outcome` sealed:
  `started(sessionId: String?, late)` (null honestly means the session was
  deleted since) | `skipped` (the previous run was still going; it is the only
  skip reason, so it carries no field) | `missed` | `failed(reason)` |
  `unknown` fallback; `reason` is a closed enum (`projectMissing`,
  `harnessUnavailable`, `modelUnavailable`, `startFailed`).
- Every wire enum (`missedRunPolicy`, `approvalMode`, failure `reason`, mark
  `kind`, `ScheduledTaskErrorCode`) has an `unknownEnumValue` fallback, so a
  newer bridge never breaks an older app's list, history or error handling.
- Every instant the app shows (`nextRunAt`, run `scheduledFor`) travels as UTC
  plus the task zone's UTC offset at that instant, as one
  `ScheduledTaskInstant(at, offsetMinutes)` value so neither half can be
  missing alone. The app renders wall-clock time from the pair and needs no
  time-zone database.
- `Session.scheduledTask`: nullable `SessionScheduledTaskMark(taskId, name,
  kind: recurring|once)`. Null honestly means "not a task run", including from
  bridges before this feature, so no compatibility default is needed.
- `PluginMetadata.supportsCompactionOnRequest` (step 10) with `@Default(false)`
  and a `COMPATIBILITY` comment: older bridges cannot run tasks, so false is
  honest.
- Can't-start push: **no new category** (the auth server stores a fixed
  per-category preference record, and the client maps categories
  exhaustively). It reuses `NotificationCategory.sessionMessage` with a new
  `NotificationEventType.scheduledTaskRunFailed` (the enum already falls back
  to `unknown`) and a new nullable `NotificationData.taskId`. Step 6 confirms
  the auth server's `/notifications/send` passes an unknown event type and
  extra `data` fields through unchanged; if it does not, that becomes an
  explicit cross-repo dependency before step 6 merges. Both wire additions
  land in step 6 with that check, not in step 2: the new required
  `NotificationData.taskId` touches every push call site that step 6 changes
  anyway.
- Routes, all new (exact paths follow `request_router.dart` conventions):
  list tasks, create, update, delete, set enabled, run now, list a task's runs.
  Validation errors are typed responses (unknown zone, unknown project/harness,
  hours out of range, empty prompt). Step 2 ships every body: the list, task,
  run and run-list responses, `CreateScheduledTaskRequest`,
  `UpdateScheduledTaskRequest`, `SetScheduledTaskEnabledRequest`, one
  `ScheduledTaskIdRequest` (delete, run now, list runs) and
  `ScheduledTaskErrorResponse` whose `ScheduledTaskErrorCode` also covers
  empty name, invalid schedule fields, a past one-off time, values the bridge
  does not know (`unsupportedByBridge`), a missing task and the Run now
  refusal (`previousRunActive`).
- One new SSE event, `scheduledTasks.changed` (no payload beyond the bridge's
  usual envelope). The Orchestrator emits it from `ScheduledTaskService`'s and
  `ScheduledTaskRunService`'s change streams on create, update, delete,
  enable and every run row written. The Scheduled and task pages refetch on it,
  so skipped, missed and failed runs and edits from another device show live.
  Older apps already ignore unknown SSE types (`ConnectionService`).

### P3. Compatibility

- **New app, older bridge:** task routes return 404. The Scheduled entry is
  still shown; the page shows "Update this computer to schedule tasks" and its
  tap opens `showBridgeUpdateSheet` (never ignore the tap). No run marks.
- **Older app, newer bridge:** tasks created from another device still run.
  Their sessions are ordinary rows without marks. Can't-start pushes arrive as
  a session-message push with an unknown event type (shown by the OS as
  usual; a tap opens the app). Completion pushes for runs are suppressed
  regardless of app version, as decided. The new SSE event is ignored.
- Within phase 1 every wire shape is unreleased until it ships, so steps may
  change each other's shapes freely before release (AGENTS.md compatibility
  baselines).

### P4. Persistence

- One migration at the next free schema version after `main` at
  implementation time (26 today; never fold into a merged version). Two tables
  plus one session column:
  - `sessions.scheduledTaskId`: nullable FK to `scheduled_tasks`, set null on
    task delete. Written by the internal creation entry (P7) in the session
    insert, together with `approvalOverride`. It is the source of the run mark
    and of the auto-archive candidate list, so trimming history never loses
    either.
  - `scheduled_tasks`: id (PK), name, prompt JSON, projectId, pluginId, agent,
    model JSON, variant, fastMode, dedicatedWorktree, schedule JSON, timeZone,
    missedRunPolicy, runMode, autoCompact, approvalMode, enabled, `nextDueAt`
    (UTC ms, nullable, **indexed**), `targetSessionId` (nullable, FK to
    sessions, set null on delete), `completedAt` (one-off done), createdAt,
    updatedAt.
  - `scheduled_task_runs`: id (PK), taskId (FK, cascade delete), sessionId
    (nullable FK, set null on delete), scheduledFor,
    `scheduledForOffsetMinutes` (the task zone's offset at that instant,
    frozen at write so a later zone edit cannot change past rows), firedAt,
    outcome, reason, late, `userPromptedAt` (nullable), `compactRequestedAt`
    (nullable); index on (taskId, firedAt) and on sessionId.
- Run rows are trimmed to the newest 20 per task when a new one is written.
  The trim never deletes the task's latest `started` row (one exclusion in the
  trim query, step 3.a): twenty skipped rows in a row must not erase the only
  row that points at a still-running session, or the overlap check (P6) would
  miss it and start a second run, breaking D8. They are the outcome history (ran, ran late, skipped, missed, couldn't
  start), not the "last 5 finished runs" of D10, which counts run *sessions*
  left unarchived. A `started` row whose session was archived links to it in
  Archived. Marks and archiving read `sessions.scheduledTaskId`.
- Deleting a task cascades its runs and nulls `sessions.scheduledTaskId`; its
  sessions remain as ordinary sessions without the mark (D15). A one-off task
  is never deleted by running: it gets `completedAt`, leaves the list and keeps
  its session's clock mark (D2).
- Task writes that race a fire: every task field a fire writes is guarded by
  the task's `updatedAt` seen at fire start. The reservation transaction (run
  row plus advanced `nextDueAt`) is conditional on it; if it fails, the fire
  reloads the task and does not fire on this pass. The later
  `targetSessionId` write after a same-session creation has the same
  condition, so an edit made in the meantime wins. A task deleted during a
  fire makes the run-row write a logged no-op. No lock is added for this.

### P5. Schedule times, zones and DST

- The app sends the device's IANA zone through a `DeviceTimeZoneSource` port
  in `module_core`, implemented once by a `flutter_timezone` adapter in
  `module_app_ui/lib/src/platform/` and registered by each shell. The task
  stores it; occurrences are computed in that zone, so 09:00 stays 09:00 across
  DST and the bridge host's own zone is irrelevant. An unknown zone is rejected
  at save.
- The bridge app adds the `timezone` package and initializes its database once
  in bridge startup, before the scheduler starts. It loads `latest_all`, since
  devices can report link names such as `UTC` or `Asia/Calcutta` that the
  smaller `latest` set lacks; the database is process-wide, so the Claude
  plugin's quota mapper loads the same set instead of replacing it (step 2).
- Wall-clock presets (once, daily, weekdays, weekly): a local time that does
  not exist (spring-forward gap) runs at the same offset into the gap after the
  jump (02:30 → 03:30); a repeated local time (fall-back) runs once, at the
  first instant.
- Every few hours: a fixed real-time interval from the chosen start, so it
  stays every N real hours across DST. When 24 is not a multiple of N the
  times drift across days; that is honest for an interval.
- For recurring schedules `nextDueAt` is recomputed on create, edit, resume
  and after every fire, always as the first occurrence strictly after "now"
  (edits change future runs only; resuming does not replay the paused period).
- A Once task's `nextDueAt` is its own instant and is never recomputed, so if
  the bridge was off at that time it is still due when it comes back and runs
  late (P6). Saving a Once time already in the past is rejected with a typed
  error; the editor prevents picking one.
- The task list and detail render times from the UTC-plus-offset pairs (P2),
  so they show the task zone's wall clock, and add the zone name when the
  offset differs from the viewing device's.

### P6. The tick, missed runs and overlap

- `ScheduledTaskTimerListener` copies the quota listener's pattern: run at
  start, then re-arm a 30 s timer after each pass. A second 30 s timer is
  cheaper and safer than merging two different policies behind one ticker.
- The listener calls only `ScheduledTaskRunService.runDue()`. All scheduler
  work (each tick's firing pass and post-run compaction pass, and Run now) is
  serialized through one async lock in that service. That is the coarsest
  mechanism that prevents a tick and a Run now from firing or compacting the
  same task twice; throughput is irrelevant at this scale.
- **Quietness has one owner:** a new `SessionRepository.getSessionQuietness`
  returning a closed enum (`quiet`, `working`, `awaitingUser`, `unknown`). It
  reads the plugin's `getActiveSessionsSummary()`, which already folds busy and
  retry status, pending questions, permissions and forms, and busy sub-agents
  (as the Running filter uses them), then `getSessionReadiness` for what a
  harness adds (queued prompts, Claude and Pi wake-ups). A backend that is not
  running reads `quiet`; an unbound session or a read error reads `unknown`.
  Lands in step 4.a; overlap (here),
  "finished" for auto-archive (P8) and compaction (P10) all use it. Nothing in
  core reads `PushSessionStateTracker`.
- Due selection: enabled tasks with `nextDueAt <= now` (indexed).
- Grace: a fire within 2 minutes of `scheduledFor` is on time; later is
  "ran late".
- Missed (first seen more than the grace after due, i.e. the bridge was off or
  the machine asleep): `runWhenBack` fires once, marked late;
  `waitForNext` writes one `missed` row. Either way `nextDueAt` becomes the
  first occurrence after now, so a week away yields one run or one missed
  row, never a pile-up. One-off tasks always run when back: the missed-run line
  is hidden for Once, because "wait for the next time" has no next time.
- Overlap (D8): a run is recorded as `skipped` when the session of
  the latest **started** run (not the latest history row: `skipped`, `missed`
  and `failed` rows have no session and must not hide an earlier active one)
  is `working` or `awaitingUser` (busy or retry, a pending question,
  permission or form, or non-idle readiness on Claude and Pi, where `queued`
  covers a pending `ScheduleWakeup` and user-queued prompts). `unknown` does
  not block: Claude reads `unknown` for a session with no transcript, which
  would otherwise block the task for good. Exception: busy because of this
  task's own pending compaction (P10). Step 4.b tests that many skipped
  occurrences in a row (more than the 20-row trim) still leave the earlier
  started run counted as active, so the next run is skipped too. A run whose
  prompt went out less than 30 seconds ago (in a new or continued session)
  counts as going whatever its session reads, since OpenCode, for one,
  reports a new turn's busy status only after the prompt call returns. This wins over the compaction exception,
  which cannot apply then: compaction waits for a quiet window (P10).
- At most once: the run row and the advanced `nextDueAt` are written in one
  transaction before the create or send is attempted, like the quota
  `consumed` marker. A crash between write and send loses that run; it never
  sends twice. The write only lands while the task's `updatedAt` is the one
  read at fire start, so an edit, pause or delete during the fire wins. A
  started row is written with no session and gets its session id after the
  create, or turns into `failed(reason)` when the create throws. A one-off
  task is completed by that same write, whatever the outcome.
- Run now: same rules, does not move `nextDueAt`; when the previous run is
  still going it returns a typed refusal and the app explains it. It writes no
  task fields, so its row is written without the `updatedAt` condition.

### P7. Firing a run

- New-session runs call an internal entry on `SessionCreationService` that:
  - skips `_recordNewSessionDefaults` (a scheduled run must not change the
    user's remembered picks);
  - writes the task's approval mode as `approvalOverride` and the task id as
    `scheduledTaskId` in the session insert. Step 4.a confirmed the insert
    precedes permission handling for the first prompt: both are written in the
    binding's commit transaction, and events for a backend session are parked
    until that commit, so no `approvePending()` call is needed;
  - keeps title generation, worktree preparation and every other validation.
- Same-session runs: the first run creates the session (as above) and stores
  `targetSessionId`. Later runs send the prompt on the session lane with the
  task's current agent, model, variant and fast mode, and set the session's
  approval override to the task's mode. If the target is archived or deleted,
  the run creates a fresh session and retargets (D9). Editing a same-session
  task's project, harness or worktree switch clears the target, so the next run
  starts fresh.
- Step 5 as built: the run sets the override through
  `YoloSettingsService.setSessionOverride` (its own lane operation), then
  dispatches `sendPromptAlreadyReserved` on the target's lane as `sendPrompt`
  or `sendCommand`. `sendPromptAlreadyReserved` takes `command` and
  `commandSource` like `sendPrompt`, so a slash-command task continues with its
  command. It is the bridge's own send and never writes `userPromptedAt`. The
  overlap check needs no target-specific read: a continuing run records the
  target as its session, so the latest started run is the target. With the
  worktree switch on, the task keeps the target's worktree (D15) until a
  retarget creates a fresh one.
- Model check: before firing, the run checks the task's model against the
  harness's current option list when one is readable; a missing model fails
  the run with `modelUnavailable` rather than letting a harness fall back
  (D15). If the list can't be read, the run proceeds and any harness error
  surfaces in the session as usual.
- A failure to start writes `failed(reason)`, logs the original error locally
  with task and project context (no prompt text), and emits a
  `ScheduledTaskRunFailure` on the run service's failure stream (P8). A
  recurring task stays enabled and tries again next time.

### P8. Marks, history, archiving and pushes

- `SessionViewService.enrich` (and the batch list path, one join per list)
  attaches `Session.scheduledTask` from `sessions.scheduledTaskId` joined to the
  task (name, once vs recurring). `session.created` therefore already carries
  the mark.
- Auto-archive (D10): when a new-session task fires, its sessions (by
  `scheduledTaskId`) older than the newest 5 finished ones are archived
  through the real archive workflow, `SessionLifecycleService.updateArchiveStatus`
  (which reaches `_doArchive`, exporting the transcript before any worktree
  removal), with the non-forced cleanup checks kept. `cleanupAlreadyReserved`
  alone only removes a worktree and does not archive. "Finished" means
  `getSessionQuietness == quiet`. Pinned, active and refused (uncommitted
  work) runs stay; a refusal is logged, not pushed. Same-session tasks have one session and archive nothing.
- Completion push (D11): the Orchestrator injects a resolver
  `Future<bool> Function({required String sessionId}) isUnattendedTaskRun`
  into `CompletionPushListener`, composed from `ScheduledTaskRepository` (same
  pattern as `resolveSessionTitle`), so `push/` never depends on core
  repositories. It is true when the session's latest run has
  `userPromptedAt == null`; such completions are not pushed. Once the user
  sends their own prompt into that session, it behaves like any session.
- `userPromptedAt` has one writer, `SessionPromptService`: its user-facing
  `sendPrompt` (behind `send_prompt_handler.dart`, and a send-to-session
  handoff) and `rewindAndSendPrompt`, through a new
  `ScheduledTaskRepository` dependency (mirroring its existing
  `SessionContinuationRepository` one). `sendPromptAlreadyReserved`, used by
  the scheduler and quota continuation, never writes it. Needs-you pushes are
  unchanged.
- Can't-start push: the Orchestrator hands the run service's failure stream to
  a new `ScheduledTaskFailurePushListener` in `push/`, which calls a new
  `PushDispatcher.dispatchScheduledTaskFailure`; `PushNotificationContentBuilder`
  builds the body (task name and a short reason). Rate-limit and collapse keys
  are per `taskId` (today they fall back to one global key when `sessionId` is
  null, which would merge two tasks failing at 09:00). The payload carries
  `taskId`; the client routes a tap to the task's page (step 8) through
  `NotificationOpenDispatcher`, which gains a task target. An older app opens
  its home.
- Step 6 as built:
  - The mark is read in `SessionViewService.enrichMany`, one join of
    `sessions.scheduledTaskId` to the task per list, so the single-session
    path, lists and `session.created` all carry it.
  - Auto-archive runs after a new-session run starts, outside the run lock and
    one pass at a time, so it never delays or fails a fire. It goes through
    `updateArchiveStatus` with `deleteWorktree: true, force: false`.
  - Pinned sessions are neither archived nor counted among the 5. A session
    whose quietness reads `unknown` counts as not finished and stays.
  - `rewindAndSendPrompt` writes `userPromptedAt` because an edit is the
    user's own prompt too, and so does a user's send-to-session handoff.
  - The can't-start push is limited and collapsed per task
    (`session_message-task-<taskId>`).
- Auth-server check (2026-11-15, `sesori_auth_server` master `4987730`): an
  unknown `eventType` passes through, because `notificationDataSchema` types
  it as `z.string()`. `taskId` is silently stripped: the plain `z.object` in
  `src/models/api.ts:294-301` drops unknown keys, and the flatten step in
  `src/services/notification-service.ts:150-163` copies only the four known
  fields. Resolved by auth-server PR #116 (live in production, `/version`
  builtAt 2026-11-16T00:31:39Z), which passes `taskId` through; step 8's push tap can rely on it.

### P9. Compaction on request (all harnesses)

- Add `BridgePluginApi.compactSession({sessionId, promptId})` returning a
  `PluginCompactionResult` enum (`accepted` | `sessionBusy` | `unsupported`; an
  enum because no variant carries data), and a
  static descriptor getter `supportsCompactionOnRequest` set from the recorded
  probes, surfaced as `PluginMetadata.supportsCompactionOnRequest`. Every
  plugin implements the method (full-surface rule); non-supporting ones return
  `unsupported`. The user-facing `compact` catalog command stays as it is.
- The flag is only a hint; the runtime `compactSession` answer is
  authoritative. An ACP harness whose live command list lacks the command, or
  OpenCode v1, answers `unsupported` even when the flag says otherwise, and
  step 11 treats `unsupported` from the call as final for that run (P10.1 sets
  `compactRequestedAt` on it).
- Implementations reuse each plugin's existing path: Claude `/compact`, Codex
  `thread/compact/start`, OpenCode v2 (v1 answers `unsupported`: its compact
  path needs a client model, and v1 is being retired), Pi RPC `compact`, Cursor
  `/summarize`. Shared ACP implements it for a harness whose native command
  list advertises compaction and returns `unsupported` when the live list
  lacks it (probe Copilot, Hermes, OMP, Grok, DeepSeek, Antigravity live and
  record each result).
- `compactSession` must not cancel work: the bridge calls it only on a `quiet`
  session, and the ACP implementation returns `sessionBusy` when a turn is
  active instead of cancelling it.
- Bridge core reaches it only through a new `SessionRepository.compactSession`
  (via `_useSessionPlugin`, with a new `SessionOperation`), never the plugin
  directly.
- Readiness has two consumers, the quota service and quietness (P6), so step
  10 renamed it to the neutral `getSessionReadiness`, `PluginSessionReadiness`
  and `SessionReadiness`; step 4.a's quietness reads that API.

### P10. Auto-compact policy (step 11)

There is **no compaction timer**. The window's activity clock is a
`ScheduledTaskActivityTracker` (bridge `Tracker`), not `sessions.lastActivityAt`:
`SessionUnseenService.recordActivity` deliberately coalesces repeated assistant
activity once a session is unseen and unviewed, which is exactly an unattended
run, so that column stops moving. The Orchestrator feeds the tracker every
plugin event for a session (and its children) that has `scheduledTaskId`; it
holds one "last activity" instant per such session in memory. After a bridge
restart the tracker starts every session at the bridge's start time, so the
window restarts and can only compact later, never early; the pre-run fallback
(case 2) still covers the next run. `ScheduledTaskRunService.runDue()`
runs, under its lock, the post-run compaction pass (case 1) and the pre-run
gate (cases 2–3), both through the injected `ScheduledTaskCompactionService`.
That service re-reads `R.compactRequestedAt` inside S's lane before sending,
so a Run now and a tick can never compact twice. Each tick, for every enabled
same-session task with auto-compact on and a harness that supports it, let R
be its latest started run and S its session (not archived).

1. **After the run.** Compact S when all hold:
   - `R.compactRequestedAt` and `R.userPromptedAt` are null (a user prompt in
     that session cancels the post-run compaction);
   - `getSessionQuietness(S) == quiet` (status idle; no pending question,
     permission or form; readiness idle where reported; on Claude, background
     tasks read busy and a pending wake-up reads `queued`);
   - `now − max(tracker.lastActivity(S), R.firedAt) ≥ W`, where W is the quiet
     window (Q1 = B): `W = min(cacheLife − 2 minutes, 25 minutes)`, and an
     unknown cache life means 25 minutes. A 5-minute cache gives about 3 quiet
     minutes; Codex (30 minutes) and Claude on a subscription (1 hour) give 25.
     Any plugin event, including every PR-monitor or background wake, moves the
     tracker's instant and so pushes the compaction back; harness signals
     (pending wake, background task, readiness not idle) only ever extend the
     wait.
   - **Cache-life source.** The plugin answers it: step 11 adds a
     plugin-interface query for a session's prompt-cache life (nullable =
     unknown). Each plugin derives it from what it already knows (evidence in
     P11): Claude reads the `promptCacheTtlSeconds` it already sets from the
     init handshake's account since #2612 (a subscription wins over an API
     provider and gives 1 hour; an API provider without a subscription gives 5
     minutes; neither gives 1 hour) and does not recompute it, so that
     precedence has one owner, Codex 30 minutes, OpenCode by provider (Anthropic 5
     minutes), Pi 5 minutes, Hermes 5 minutes, Cursor by model (Anthropic 5
     minutes), Oh My Pi per seat. Copilot, Antigravity (Gemini) and Grok report
     unknown. The margin and cap live only in `ScheduledTaskCompactionService`
     in bridge core, and no harness names appear in core.
   - Hermes `/compress` keeps the ACP session id (live-verified on
     v0.21.5+2453 through the ACP adapter); only Hermes' internal head id
     rotates on automatic compression, and Sesori never uses it. No plugin
     change needed; step 11 adds this line to docs/HARNESS_CAPABILITIES.md.
   The compaction runs on S's lane, re-checks quietness and
   `R.compactRequestedAt` inside the lane, calls
   `SessionRepository.compactSession`, and sets `R.compactRequestedAt` on
   `accepted` and on a failed send (logged), so the tick never retries every
   30 s. `sessionBusy` leaves it unset for a later tick; `unsupported` sets it.
2. **Before the next run (fallback).** When a run (scheduled or Run now) comes
   due and `R.compactRequestedAt` is null (the window had not passed, the user
   prompted, the run was waiting on the user, or compaction was unsupported at
   the time), and S is `quiet`: compact first, set `R.compactRequestedAt`, and
   fire on a later tick once S is quiet again. This covers a next run due inside the
   window and any state from before a restart.
3. **Compaction still running when a run is due.** S busy with
   `R.compactRequestedAt` set: the run waits (stays due) up to 10 minutes
   after `compactRequestedAt`, then fires when idle, or records
   `skipped` and advances if still busy. A run delayed past
   the grace by compaction is marked late; accepted.
4. **Edits mid-window.** Auto-compact turned off, switched to new session,
   project/harness changed (target cleared), task paused or deleted: the next
   tick finds no candidate, so nothing compacts. Pausing stops automation on
   that session entirely.
5. **Accepted limits.** A harness's own automatic compaction is not detected,
   so the bridge may compact once more (a summary of a summary; cheap). An
   external wake slower than W can land in a compacted session; the agent
   continues from the summary. On a 5-minute cache route W is about 3 minutes,
   so a PR-monitor wake after that lands in an already-compacted session; the
   user accepted this with Q1 = B. No harness exposes a signal for future
   external wakes.
6. **Client.** The Each run sheet shows the switch only for Continue in the
   same session. When the chosen harness lacks
   `supportsCompactionOnRequest`, the switch is shown off and inert, and a tap
   explains "<Harness> can't compact on request".

### P11. Prompt-cache TTL findings (2026-11-15)

| Harness | Default cache life after last use | Warm at 25 min? |
|---|---|---|
| Claude Code | 1 h on a subscription within plan usage; 5 min with API key, Bedrock/Vertex or usage credits; sub-agents 5 min. `CLAUDE_CODE_PROMPT_CACHE_TTL=1h` / `ENABLE_PROMPT_CACHING_1H` extend it. | Subscription yes; API key no |
| Codex | GPT-5.6+: at least 30 min, each read extends it. GPT-5.1–5.5: usually ~30 min, up to 24 h (non-ZDR). Codex sends `prompt_cache_key`, no explicit TTL. | Usually yes |
| OpenCode | Anthropic 5 min (no TTL sent); per-model `cache.ttl` and opt-in warming exist, off by default. | Anthropic no |
| Pi | "short": 5 min on Anthropic; `PI_CACHE_RETENTION=long` gives 1 h. Pi's compaction request is sent uncached anyway. | No (irrelevant to compaction) |
| Oh My Pi | Like Pi; Anthropic subscription seats default to 1 h. | Subscription yes |
| Hermes | `cache_ttl` default 5 min; `1h` or `auto` available. | No |
| Cursor | Anthropic 5 min, most OpenAI 24 h, GPT-5.6 30 min (Cursor staff). | Model-dependent |
| Copilot | Not published; Anthropic presumably 5 min, OpenAI 24 h retention in VS Code. | Unknown |
| DeepSeek | Disk cache, hours to days. | Yes |
| Antigravity (Gemini) | Implicit, best effort, undocumented TTL. | Unknown |
| Grok | Undocumented, evicted under memory pressure. | Unknown |

Sources: Claude Code prompt-caching and env-var docs, OpenAI prompt-caching
guide, Cursor forum staff answer, VS Code Copilot token-efficiency blog, open
source of Codex, OpenCode, pi-mono, Oh My Pi and Hermes, DeepSeek KV-cache
guide, xAI caching docs, Vertex context-cache overview.

What it means:

- Compacting cold costs about one full uncached read of the context instead of
  roughly 0.1× for a warm read. A cold compaction is still never worse than the
  round-2 "compact before the next run", because the next run, hours later,
  reads cold anyway. Warm compaction saves about 0.9× of one context read per
  run.
- A 25-minute window stays warm for Claude Code on a subscription, Codex,
  Oh My Pi on a subscription and DeepSeek. It goes cold on every default
  5-minute Anthropic route (Claude Code with an API key or cloud provider,
  OpenCode, Hermes, Cursor's and probably Copilot's Anthropic models).
- No harness can tell whether an external sender (an MCP monitor, a peer
  message) will wake the session later, so harness signals can only *extend*
  the window, never prove "done".
- Q1 = B outcome: the window follows each session's cache life, so post-run
  compaction reads warm wherever the cache life is known (about 3 minutes on
  5-minute routes, 25 minutes on Codex and Claude subscriptions). Cache life is
  not extended at launch, so cache writes keep their 1.25× price.

### P12. Analytics

- `scheduled_task_saved` (account-linked, `ProductAnalyticsService`), fired
  by the editor's save path on the bridge's success response only. Closed
  parameters: `action` (created, edited), `repeat_kind` (once, daily,
  weekdays, weekly, every_hours), `run_mode` (new_session, same_session),
  `approval_mode` (ask, approve_all), `missed_run_policy` (run_when_back,
  wait_for_next), `auto_compact` (boolean, same-session only). Answers: is the
  feature adopted, and which shapes matter (same-session, approvals) for the
  MCP phase.
- Screen mapping for the new routes (`scheduled_tasks`,
  `scheduled_task_detail`, `scheduled_task_editor`) in the exhaustive
  `AnalyticsScreen` map.
- **Run outcomes are not tracked in phase 1.** Runs happen headlessly on the
  bridge, which has no analytics pipeline; reconstructing them in the app
  would miss headless runs and double-count across devices. This narrows the
  round-1 note ("task run" events); see "Decided without asking" in the
  report.
- Warehouse: add the event to the curated product-events transform with a
  fixture assertion, per the add-analytics checklist.

### P13. Composer reuse (client)

- `NewSessionCubit` is created with a sealed `NewSessionPurpose`:
  `startSession()` (today) or `editTask(initialSelection)`, where the
  selection (project, harness, agent, model, variant, fast mode, worktree,
  prompt, staged command) is non-null and may be the defaults for a new task.
  In `editTask` the cubit uses its own draft slot (never the new-session
  draft), writes no remembered picks, hides attachments, fires no new-session
  analytics, and on submit emits a submitted-selection state instead of
  launching.
  As built in step 7: `startSession(project)` carries its project and the
  task selection carries its own, so the cubit takes only the purpose. A
  task's draft lives in the cubit only (one task's unsaved text never shows in
  another's composer), and its picks go to a `NewSessionSelectionTracker` of
  its own, seeded with the task's harness and picks when it has them. First
  discovery opens on that harness by id. Save waits for the harness' options
  and hands the content over through `PromptSubmitAction`, so the composer
  keeps it. The submitted selection is the `NewSessionPhase.taskSubmitted`
  phase, so the composer stays editable after a failed save;
  `TaskComposerSubmission` keeps identity equality, so saving the same
  choices twice reaches the listener twice.
- `NewSessionView` gains a header slot above the composer (the When and Each
  run lines) and a submit label/icon (Save task) passed down to `PromptInput`.
- `ScheduledTaskEditorCubit` owns When and Each run state, defaults,
  validation and `save(selection)`. The editor screen's `BlocListener` on the
  new-session cubit forwards the submitted selection to
  `ScheduledTaskEditorCubit.save`. Neither cubit references the other, and no
  callbacks are passed into a cubit.
- Defaults: When = Every day at 09:00 in the device zone; missed = Run when
  back; Each run = New session; approvals = the computer's current YOLO
  setting; auto-compact = on when the harness supports it (only matters for
  same session).
- The time field is a new `module_prego` component built on Flutter's
  Cupertino date picker in time and date-and-time modes, inside
  `showPregoModal` (sheet on touch, popover/dialog on pointer).
- As built in step 9.a: the editor cubit keeps the wire `TaskSchedule` and
  `TaskRunMode` as its state, so switching presets carries the time of day
  over (a one-off or interval start lands on the next time that clock time
  comes round; Weekly starts on today). Client checks reuse the bridge's
  `ScheduledTaskErrorCode`s (empty prompt, weekly with no days, a past
  one-off time for a new task). An edit keeps the task's zone; only a new
  task's one-off time is judged on the device clock, the bridge judges the
  rest. Same session saves `autoCompact: false` (or the edited task's value)
  until step 11 adds the switch and its harness-based default. The name is
  the prompt's first line (80 characters at most); an edit keeps a name the
  user changed and follows the prompt otherwise, and renaming stays on the
  task page. A command without a source saves as a plain command.
  `scheduled_task_saved` is not sent from desktop until the auth server
  accepts it (`DesktopProductAnalyticsDeliveryService` maps it to null).

## Explicitly Excluded From Phase 1

- Scheduling from an open session or the send button (D1).
- Custom cron, natural-language schedules, attachments in task prompts.
- A cross-computer task list; tasks moving between computers.
- Waking a sleeping machine for a run (`pmset` schedules).
- Run-outcome analytics (P12).
- A separate push category or preference toggle for task pushes (P2).
- Harness-launch cache-TTL changes (P11); Q1 = B does not need them.

## Security And Privacy

- Task prompts are stored in the bridge's local database like session data
  and travel only through the encrypted relay. Logs record task id, project
  and harness context and errors, never prompt text.
- "Approve everything" runs commands unattended; it is the user's explicit
  per-task choice, defaulting to the computer's existing setting. Questions
  still wait and push.
- Pushes carry the task name (the prompt's first line, like session titles in
  existing pushes) and a closed reason. Analytics carry closed values only.

## Complexity Budget

New persistent parts: two tables (`scheduled_tasks`, `scheduled_task_runs`)
including the `userPromptedAt` and `compactRequestedAt` run columns, one
`sessions.scheduledTaskId` column, one nullable `Session` wire field, one
`PluginMetadata` flag, one notification event type and `taskId` payload
field, one SSE event. In-memory: one 30 s timer, one scheduler lock, one
per-session activity instant for task-run sessions only
(`ScheduledTaskActivityTracker`, needed because `lastActivityAt` coalesces
unattended activity), and two
change/failure streams consumed by the Orchestrator (one feeding the new
`ScheduledTaskFailurePushListener`). Each is justified by a decided behavior
(D7–D13) or by an ownership rule (pushes through a listener, SSE decisions in
the Orchestrator).

Deliberately not added: quiet timers (the tick compares the tracker's instant),
a persisted activity column (a restart conservatively restarts the window), a generic scheduler shared with quota
continuation, detection of harness-native compaction, optimistic concurrency
for two devices editing one task at the same moment (last write wins), a
consecutive-failure auto-pause, a new push category.

## Cleanup Assessment

- Step 10 renamed `getQuotaContinuationReadiness` and its types to neutral
  `getSessionReadiness` names for their second consumer (done).
- No other code becomes obsolete. The quota timer stays separate on purpose
  (P6); `bridge/app` never sends the `compact` command today, so the new typed
  method replaces nothing.

## Proportionality And Accepted Risk

| Case | Evidence | Handling |
|---|---|---|
| Crash between run write and send | Theoretical | Run lost, never doubled (P6). |
| Early permission before override lands | Only if a plugin inserts the session row late | One possible push; accepted (P7). |
| Task edited while a fire is creating its session | Rare | Conditional target write; the edit wins (P4). |
| Two devices edit one task at once | Theoretical | Last write wins. |
| External wake slower than W | Ordinary (monitors) | Lands in a compacted session; agent continues (P10.5). |
| Harness auto-compacted already | Ordinary | One extra cheap compaction. |
| Compaction in flight at restart | Rare | Treated as compacted; next run uncompacted. |
| Daily failure pushes when a harness is gone | Ordinary | Accepted; each push names the reason. |

## Regression Coverage

- **New feature document:** `docs/regression/scheduled-tasks.md` (step 12):
  task CRUD and validation, schedule times and DST, missed and overlap rules,
  new- and same-session runs, approvals, run marks, auto-archive, push policy,
  auto-compact, older-peer behavior, analytics.
- **Updated documents:** `notifications.md` (completion suppression,
  can't-start push), `session-archiving-and-deletion.md` (automatic archiving
  of runs), `permission-auto-approval.md` (per-task approvals),
  `projects-and-sessions.md` (run marks), `analytics.md` (new event and
  screens), and `docs/HARNESS_CAPABILITIES.md` (compaction on request, step 10).
- **Retirement level: L3** for `scheduled-tasks.md`, plus the L2 entries the
  updated documents gain.
- **Matrix:**
  - Automated: occurrence calculator (zones, DST gap and overlap, every-hours,
    missed decisions), migration test, mappers, cubits and widgets.
  - Headless bridge: CRUD routes; firing a one-off a few minutes ahead;
    missed run across a bridge stop (both policies); overlap skip; Run now
    refusal; at-most-once after a forced crash; auto-archive refusal on
    uncommitted work; completion suppression and can't-start push dispatch
    (debug events).
  - Live plugin: run firing is **Representative** (Claude Code and Codex);
    compaction on request is **Every supporting production plugin**;
    the auto-compact policy is Representative with Claude (readiness path)
    and Codex (status-only path).
  - Client end to end on a headless iOS simulator (`xcrun simctl boot`, the
    device the local-testing skill assigns): Scheduled page with both
    headings, New task screen with both sheets, save and edit, Run now, marks
    on rows, older-bridge update sheet against a v1.14.0 bridge.
  - Packaged or external: push receipt on a device is not part of L3 (no
    iOS-simulator FCM delivery); the headless dispatch check covers L3.

## Delivery Rules

- PR titles are fixed in [TRACKER.md](TRACKER.md). Use
  `<emoji> [scheduled-tasks] <description> [step x/18]`.
- Soft cap ~1,500 changed lines; lower for lifecycle steps (4.b, 5, 11). Drift
  and Freezed output can push steps 2 and 3.a over; report generated versus
  authored lines. Clean splits (for example 8.a/8.b, 9.a/9.b) need no
  permission.
- Worktrees go under `~/.claude-worktrees/sesori_apps_monorepo/<name>`.
- On-screen checks only on a headless iOS simulator.
- Each step ships behind no flag; user-visible entry points arrive only in
  step 9, so main never shows a Scheduled page without a way to add a task.
- Steps 4.b, 5 and 11 touch the orchestrator or session lanes: keep them free of
  unrelated refactors.
- Coordinate with the active `side-questions` plan if step 7 touches
  `PromptInput`; rebase rather than duplicate.

## Steps

Dependencies in brackets. Steps 7 and 10 can start right after step 1, in
parallel with the bridge chain.

1. 🌱 **Raise the plan.** This document and the tracker. [—]
2. ⚙️ **Task contract and schedule times.** `sesori_shared` DTOs (P2), the
   bridge `ScheduledTaskOccurrenceCalculator` with the `timezone` package and
   its tests (P5), the pure missed-run/grace decision (P6). No routes or
   storage. [1]
3. Split in two because the authored diff ran over its target.
   - 3.a 🚧 **Store tasks on the bridge.** Migration, tables and the
     `sessions.scheduledTaskId` column (P4), DAO, repository and
     `ScheduledTaskService` (validation, `nextDueAt`, change stream). [2]
   - 3.b ⚙️ **Serve the task routes.** Handlers for list, create, update,
     delete, enabled and runs, and the `scheduledTasks.changed` SSE event from
     the Orchestrator. Nothing fires yet. [3.a]
4. Split in two because the diff ran over its 1,000-line target.
   - 4.a ⚙️ **Read session quietness and start scheduled-run sessions.**
     `SessionRepository.getSessionQuietness` (P6) and the internal creation
     entry writing `approvalOverride` and `scheduledTaskId` with no
     remembered picks (P7). No caller yet. [3.b]
   - 4.b 🚧 **Fire new-session runs.** Timer listener,
     `ScheduledTaskRunService` (due selection, grace, missed policies, overlap
     skip, at-most-once, failure reasons and failure stream, one-off
     completion), the model check, Run now. [4.a]
5. 🚧 **Continue same-session tasks.** First run creates and targets the
   session (conditional target write); later runs send on its lane with the
   task's options and approval override; fresh session when the target is
   gone; edits that clear the target. [4.b]
6. ⚙️ **Marks, automatic archiving and pushes.** `Session.scheduledTask`
   enrichment from the session column, auto-archive beyond the last 5
   finished runs, completion suppression through the injected resolver and
   the `userPromptedAt` writer, `ScheduledTaskFailurePushListener` with
   per-task keys and the `taskId` payload, the auth-server pass-through check
   (P8). [5]
7. ⚙️ **Let the new-session composer serve a task editor.** Client refactor
   with no visible change (P13): sealed `NewSessionPurpose`, own draft slot,
   submitted-selection state, header slot, submit label. [1]
8. Split in two: the marks and the push tap need step 6, the pages do not.
   - 8.a Split again because the pages ran over the soft cap.
     - 8.a.1 ⚙️ **Scheduled-task client core.** `module_core` API,
       repository and the list and task cubits, refreshed by
       `scheduledTasks.changed`, with the older-bridge result. [3.b, 4.b]
     - 8.a.2 ⚙️ **Scheduled page and task page.** Routes in both shells; the
       list with Recurring/Once headings and switches; the task page with
       history, Run now, Pause/Resume, Rename and Delete; the older-bridge
       state; screen analytics mapping. Entry points stay unwired. [8.a.1]
   - 8.b 🌿 **Run marks and task pushes.** Repeat/clock marks with the task
     name in the row meta line, after the state and before the project,
     rendered from the merged `Session.scheduledTask` field; the push tap to a
     task page through `NotificationOpenDispatcher`, which needs step 6's
     `taskId` payload. A notification open now carries a sealed
     `NotificationOpenTarget` (session or task); a task opens over the
     Scheduled page, so Back passes through the list. [6, 8.a.2]
9. Split in two because the editor ran over the soft cap.
   - 9.a 🚧 **Task editor core, time fields and device time zone.**
     `ScheduledTaskEditorCubit` (P13 defaults, validation, create and edit,
     `scheduled_task_saved`), the create route's API and repository call, the
     `module_prego` date and time field, and the `DeviceTimeZoneSource` port
     with its one `flutter_timezone` adapter in `module_app_ui`, registered by
     both shells. No screen yet. [4.b, 7, 8.a.2]
   - 9.b 🚧 **New task screen.** When and Each run lines and sheets
     (missed-run line hidden for Once); save and edit; the `+` on the
     Scheduled page and Edit on the task page; entry points next to Archived
     (phone Settings, desktop sidebar and palette); the editor's screen
     mapping. [9.a]
10. ⚙️ **Compaction on request in every harness that can.**
    `compactSession`, `PluginCompactionResult` and
    `supportsCompactionOnRequest` (P9) across all plugins,
    `SessionRepository.compactSession`, live ACP probes, the readiness rename,
    a "Compaction on request" table in `docs/HARNESS_CAPABILITIES.md`. [1]
11. 🚧 **Auto-compact same-session tasks.** `ScheduledTaskCompactionService`
    and `ScheduledTaskActivityTracker` in the tick (P10 cases 1–4), the auto-compact switch and its
    unsupported-harness tap on the Each run sheet, and the plugin-interface
    prompt-cache-life query. Uses Q1 = B. [5, 9.b, 10]
12. 🌱 **Regression docs.** Write `scheduled-tasks.md`, update the documents
    listed under Regression Coverage and the README index. [2–11]
13. 🌱 **Run the L3 regression and retire the plan.** Run the matrix above,
    record the result, move the plan to `.plan/completed/`. [12]

## Later Phases (rough intent only)

- **Sesori MCP tool for agents.** A Sesori MCP server injected when the bridge
  starts a harness, so an agent can list, create, pause and run tasks through
  the same bridge services the app uses. Why: the user's stated direction is
  agent-driven control ("query/schedule tasks"), and humans and automation
  should share one API seam (North Star).
- It needs its own plan, including which harnesses accept an injected MCP
  server, how a task created by an agent is attributed and confirmed, and
  whether agent-created tasks may use "Approve everything".

## Open Questions

None open.

- **Q1. Auto-compact quiet window: resolved 2026-11-15 as B**, a window that
  follows each session's prompt-cache life (P10). Not chosen: A, one 25-minute
  window everywhere; C, A plus a 1-hour cache for task-run sessions.

## Plan Review Record

- 2026-11-15, `architecture-plan-review` (sub-agent): **rejected** with 14
  concrete findings, none of them "too vague". All were valid and are applied
  without re-review, as the repository rules require: reuse an existing push
  category with a new event type and `taskId`; a dedicated failure push
  listener with per-task keys; an injected completion-suppression resolver
  and one named `userPromptedAt` writer; a `sessions.scheduledTaskId` column
  as the mark and archive source; nullable `started.sessionId` and unknown
  fallbacks on every wire union and enum; one `scheduledTasks.changed` SSE
  event instead of refetch heuristics; one lock-holding owner for firing and
  compaction; one `getSessionQuietness` owner; named collaborators and
  placements; a sealed `NewSessionPurpose` with listener forwarding; one
  time-zone adapter and UTC-plus-offset instants; corrected step
  dependencies and the push-tap route; a sealed compaction result through
  `SessionRepository`; a conditional target write. This revised version has
  not been re-reviewed.
