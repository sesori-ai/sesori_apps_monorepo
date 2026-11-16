# Scheduled Tasks

## Capability

A user saves a task once: a prompt, where it runs, when, and how each run behaves. The bridge stores it and runs it
headlessly, once or on repeat, with every app closed. Tasks belong to one computer. A **Scheduled** page (from Settings
on phone and tablet; on desktop from a sidebar row under Archived and the command palette, which also offers New task)
lists them under Recurring and Once headings, a heading absent when empty, recurring rows with an on/off switch. Each
task has a page with its run history, Run now, Pause or Resume, Edit, Rename and Delete. The New task screen reuses the
new-session composer with **When** and **Each run** lines above it and a Save task button. A run is an ordinary session marked with the task. The user hears about a run only when it needs
them or can't start. Same-session tasks can compact their session between runs (auto-compact).

## Required Behavior

### Tasks and validation

- Routes: `GET /scheduled-tasks` lists the tasks not yet done, each with its newest run; `/scheduled-task/create`,
  `update`, `delete`, `enabled`, `run-now` and `runs` act on one task. Every refusal is a typed
  `ScheduledTaskErrorCode`: empty name or prompt, invalid schedule fields, hours outside 1–12, unknown time zone,
  harness or project, a one-off time already past, a value the bridge doesn't know (`unsupportedByBridge`), a missing
  or done task, and Run now's `previousRunActive`.
- The editor checks an empty prompt, a weekly task with no day, and a new task's past one-off time before sending, with
  the bridge's codes and copy. A refusal leaves the editor editable with its content kept.
- A task saves its prompt (text or slash command, no attachments), project, harness, agent, model, effort, fast mode,
  worktree switch, schedule, the device's IANA zone, missed-run policy, run mode and approval mode. Its name is the
  prompt's first line (80 characters at most); renaming is on the task page, and an edit keeps a name the user chose.
- An edit replaces the definition and changes future runs only. A paused task stays paused. Changing a same-session
  task's project, harness or worktree switch, or moving it to New session, clears its session, so the next run starts
  fresh. An edit keeps the task's zone.
- Pausing clears the next run; resuming computes the first time after now, so the paused period never replays.
- Deleting a task removes it and its history; the sessions it started stay as ordinary sessions without a mark.
- A one-off task completes on its fire, whatever the outcome, and leaves the list; its session keeps the clock mark.
- History keeps each task's newest 20 rows (ran, ran late, skipped, missed, couldn't start) and never trims the latest
  started row, so a long run of skips can't hide a run still going.
- Every create, edit, pause, delete and history row emits `scheduledTasks.changed`. The Scheduled and task pages
  refetch on it, so another device's edits and new run rows appear without a reload.

### Schedules, zones and missed runs

- Presets: Once (date and time), Every day, Weekdays, Weekly (chosen days), Every few hours (1–12, from a start).
  Times are computed in the task's zone, so 09:00 stays 09:00 across DST and the bridge host's zone is irrelevant.
- A wall-clock time inside a spring-forward gap runs as far past the jump as it was into the gap (02:30 runs at 03:30);
  a time that happens twice at fall-back runs once, at the first instant. Every few hours is a fixed real-time interval
  from its start and drifts across days when 24 is not a multiple of it.
- The list and task page show times in the task zone's wall clock, adding the zone name when its offset differs from
  the viewing device's. A paused task that never ran has no offset to compare, so it names its zone unless the zone is
  the device's own. History rows keep the offset they were written with.
- A fire within 2 minutes of its time is on time; later is "Ran late". A task first seen due later than that (bridge
  off or machine asleep) follows its policy: **Run when it's back** (default) fires once, marked late; **Wait for the
  next time** writes one "Missed" row. Either way the next run is the first time after now, so a week away gives one
  run or one row, never a pile-up. Once always runs when back, and its sheet hides the choice.
- **Overlap:** while the latest started run's session is working or waiting on the user, or its prompt went out less
  than 30 seconds ago, a due run is recorded "Skipped: the previous run was still going" and the task advances. A
  session whose state reads unknown does not block.
- At most once: the history row and the advanced next run are written before the prompt is sent, and only while the
  task is unchanged since the fire began; an edit, pause or delete during a fire wins.

### Firing a run

- **New session:** each run creates a session with the task's options and its own worktree when the switch is on. A run
  never changes the user's remembered new-session picks.
- **Continue in the same session:** the first run creates the session and targets it; later runs send on its lane with
  the task's current options. An archived or deleted target is replaced: the run starts a fresh session and continues
  there from then on.
- Before firing, the task's model is checked against the harness's option list when one is readable; a model no longer
  offered fails the run ("its model isn't offered anymore") instead of falling back. An unreadable list lets the run go
  ahead. Stale agent, effort or fast mode is corrected once against the rediscovered catalog.
- A run that can't start records "Couldn't start: <reason>" (project gone, harness unavailable, model not offered, the
  session didn't start) and logs the error with task and project context but no prompt text. A scheduled run also
  pushes. A recurring task stays enabled and tries again next time.
- **Run now** fires by the same rules without moving the next run and never compacts first. While the previous run is
  still going (including a compaction in progress) it is refused, and the task page says "The previous run is still
  going. Try again once it finishes." Success shows "Run started"; a start failure shows its reason in the page's alert and sends no push.

### Run history rows

- A started run's row carries an arrow and opens its session over the task page, the way a session row opens from
  the list; Back returns to the task. An archived run session opens read as archived. The session opens under the
  task's current project, so a task moved to another project after the run can leave that session's page unable to
  load.
- A started run whose session was deleted has no arrow; a tap answers "This run's session was deleted."
- A failed run's row keeps its short "Couldn't start: <reason>" line and carries an arrow. A tap opens a small sheet
  (a dialog under a pointer) over the unmoved page, saying what went wrong and what to do next. It names no project,
  harness or model: a run records only its reason and the task carries no edit time, so a task edited since the run
  (often through this very sheet's Edit task) would otherwise be named wrongly. For a project, harness or model failure
  on a task this app can edit, the sheet offers Edit task. A start failure points at the bridge log and Run now; a
  reason from a newer bridge asks for an app update.
- Skipped, missed and unknown rows have nothing more to show and no arrow.

### Approvals, marks, archiving and pushes

- Approvals: **Ask me** or **Approve everything**, defaulting to the computer's current YOLO setting. The mode is
  stored as the run session's explicit approval override, and a same-session run sets it again before each prompt.
  Questions are never auto-answered.
- Run rows carry the task in the session row's meta line, after the state and before the project: a repeat glyph for
  a recurring task, a clock for a one-off or a calendar for a kind this app doesn't know, then its name, on one line
  that ellipsizes. Screen readers hear "Run of recurring task <name>", "Run of one-time task <name>" or "Run of
  scheduled task <name>". The mark comes from the session, so it survives history trimming, and deleting the task
  removes it.
- After a new-session run starts, the task's finished run sessions beyond the newest 5 are archived through the normal
  archive flow, removing their worktrees. Pinned sessions are neither archived nor counted; a session working, waiting
  on the user or reading unknown stays; a worktree the cleanup checks refuse (uncommitted work) keeps its session, and
  the refusal is logged, never pushed. Archiving never delays or fails a fire. Same-session tasks archive nothing.
- A run's "turn completed" push is suppressed until the user sends their own prompt (or edit, or handoff) into that
  session; each new run suppresses it again. Question and permission pushes are unchanged.
- A scheduled run that can't start pushes once (Run now answers in its alert instead): title the task name, body a short reason, no session. It is limited and collapsed
  per task, so two tasks failing at once don't merge. Tapping it opens the task page over Scheduled (see
  [Notifications](notifications.md)).

### Auto-compact

- Only same-session tasks with auto-compact on, while enabled. The bridge asks each run's session at most once.
- **Quiet window:** `min(cache life − 2 minutes, 25 minutes)`, 25 minutes when the harness reports no cache life,
  measured from the later of the session's last activity and the run's fire time. Any session status, message or part
  event moves the activity clock, so a monitor or background wake pushes the compaction back.
- **After the run**, a pass compacts once when the window has passed, the session is quiet, the user hasn't prompted
  in it since the run, and it isn't archived. The check repeats on the session's lane just before sending.
- **Answers:** busy leaves the run unmarked for a later pass; accepted, unsupported and a failed send each record
  `compactRequestedAt`, so no pass asks again for that run.
- **A run due first** (inside the window, after a user prompt, or with nothing asked yet) compacts its quiet session
  before firing and is held while the session works, for up to 10 minutes after the compaction was asked for, then
  fires when quiet or is skipped as overlapping. A busy, unsupported or failed answer fires at once. Past the 2-minute
  grace, a run a pass actually held counts as late, never missed, even under Wait for the next time.
- **After a bridge restart** the activity clock starts at the bridge's start, so the window restarts and can't pass
  early. The saved ask still holds a due run while the session works, up to the same 10 minutes after it, but the
  bridge forgets that it held the run, so past the grace it follows its missed-run policy.
- Auto-compact follows the task's current target only. An edit that changes the project, harness or worktree clears
  the target: the old session is never compacted, and the next run starts a fresh session without waiting.
- Turning auto-compact off, moving to New session, or pausing the task stops it for that session.

### Editor

- New task defaults: Every day at 09:00 in the device's zone, Run when it's back, New session, approvals as above.
  Save task works after picking only a time. Save waits for the composer's harness options.
- The When and Each run lines open small sheets (a sheet on touch, a popover or dialog under a pointer); nothing on
  the screen behind moves, and each choice applies at once to its line.
- **When sheet:** the presets, then the date-and-time, time, or hours stepper and start fields (− and + disable at 1
  and 12), seven weekday toggles on one row for Weekly (screen readers hear each full day name), and "If the computer
  was off" with its two choices for every preset but Once. Switching presets keeps the time of day.
- **Each run sheet:** New session or Continue in the same session; the Auto-compact switch, shown only under Continue;
  then Approvals. Continuing turns the switch on, or as the edited task had it. For a harness without
  `supportsCompactionOnRequest` the switch reads off and is inert, and a tap on its row explains "<Harness> can't
  compact on request". Save stores auto-compact on only when the chosen harness supports it; the switch itself keeps
  its choice, so moving back to a harness that can compact finds it unchanged.
- **Motion:** the Auto-compact row enters and leaves with the shared banner motion (size and fade, 200 ms ease-out),
  and the Approvals rows glide with it. The When sheet's weekday row and missed-run section fold in and out with the
  same motion, the field group eases when Every few hours adds its second row, and
  the sheet follows. With reduced motion each makes room at once and only fades.

### Older peers and newer values

- **New app, older bridge:** the Scheduled entry still shows. The Scheduled page, task page and editor show "Update this
  computer to schedule tasks", and a tap opens the bridge update steps. Rows carry no marks.
- **Older app, newer bridge:** tasks created elsewhere still run; their sessions are unmarked rows; a can't-start push
  arrives as an ordinary session-message push the OS shows, whose tap opens the app; completion pushes stay suppressed;
  the SSE event is ignored.
- A task with a schedule kind, run mode or value this app doesn't know stays listed, read-only, with "Edit on a newer
  app"; an unknown run outcome reads "Updated app needed to show this run". The bridge refuses values it doesn't know.

### Analytics

- The phone reports `scheduled_task_saved` once per save the bridge accepted, with `action` (`created`, `edited`),
  `repeat_kind`, `run_mode`, `approval_mode`, `missed_run_policy` for repeating tasks only (Once omits it), and
  `auto_compact` for same-session tasks only.
  The Scheduled page and task page report `scheduled_tasks` and `scheduled_task_detail`.
- Held: the desktop drops `scheduled_task_saved` and the editor reports no screen on either app, until the auth server
  accepts them (sesori_auth_server #119). Run outcomes are not tracked: runs happen on the bridge, which has no
  analytics pipeline.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included: tasks are not a product heartbeat. |
| L2 Routine | Automated: the occurrence calculator (zones, DST gap and overlap, every few hours, grace and missed decisions), the migration, repository history trim, run service (overlap, Run now refusal, at-most-once, failure reasons, auto-archive, the auto-compact group), handler, failure push listener and completion suppression suites; shared wire decoding with unknown fallbacks; editor, list and detail cubits; sheet, editor, list, task page (run row taps and the failure sheet) and formatter widgets. Headless bridge, representative plugin: create, edit, pause, resume and delete through the routes, and a one-off fired a few minutes ahead. |
| L3 Release | Headless bridge: missed runs across a bridge stop under both policies, an overlap skip, Run now refused while a run works, a forced crash between reservation and send losing the run without a second send, auto-archive keeping pinned, busy and uncommitted-work sessions, completion suppression and the can't-start push dispatch in debug events. Live plugin through the local 9router proxy: run firing is Representative (Claude Code and Codex, new and same session, an archived target replaced); compaction on request is Every supporting production plugin; the auto-compact policy is Representative with Claude (readiness path) and Codex (status-only path): one compaction after the window, a run due first compacting and held, a user prompt cancelling the post-run compaction. Client end to end on a headless iOS simulator (`xcrun simctl boot`, the device the local-testing setup assigns): the Scheduled page with both headings and switches, the New task screen with both sheets and their feel checks, save and edit, Run now and its refusal, a failed run's sheet, a run opening its session and Back returning to the task, the deleted-session answer, marks on rows, the inert Auto-compact switch and its explanation, and the update row against a v1.13.1 bridge. |
| L4 Extended | Relay integration: two clients see one task's edits and runs live. Headless bridge with a controlled clock: a real DST transition in a non-UTC zone, a restart during a held run and inside a quiet window, a long run of skips past the history trim, and an edit racing a fire. Older v1.13.1 app against this bridge: tasks run, rows unmarked, completion suppressed. |
| L5 Full | Packaged or external: can't-start push receipt and tap on a real device; a week-long recurring task across machine sleep; analytics rows upstream once the auth server accepts them. |

The headless dispatch check covers pushes at L3; device receipt needs FCM, which the iOS simulator lacks. A widget
render cannot pass a client end-to-end cell, and a missing harness or proxy makes its live cell Blocked, not passed.

## Exploration Guidance

Vary the schedule kind, the zone (one whose offset differs from the device's), and the time relative to the grace.
Stop the bridge across a due time, leave a run waiting on a permission when the next falls due, archive or delete a
same-session target between runs, and prompt into a run session before its quiet window passes. Change harness in the
editor between one that can compact and one that can't. Use fixture projects and prompts only.

## Material Failure Signals

- A task fires twice for one time, piles up runs after downtime, or replays a paused period.
- A DST change moves a wall-clock task off its local time, or a gap or repeated time runs twice or never.
- A missed run under Wait for the next time fires, or one under Run when it's back is recorded missed.
- A run starts while the previous one works or waits on the user, or an unknown session blocks a task for good.
- A run changes the user's remembered picks, swaps in another model, or continues in an archived session.
- Auto-archive removes a pinned, busy or uncommitted-work session, or the kept count includes pinned sessions.
- A finished run pushes "turn completed" before the user prompts in it, a needs-you push is lost, or two tasks' failure
  pushes collapse into one.
- Auto-compact compacts a session an edit moved the task away from, sends while the session works, cancels a turn, asks twice for one run, compacts before the window or
  after a user prompt, or retries every pass after an unsupported or failed answer.
- A held run is recorded missed, waits past 10 minutes, or Run now compacts first or pushes its start failure.
- The Auto-compact switch shows under New session, toggles on a harness that can't compact, or a tap on it does nothing.
- A run row tap does nothing, opens the wrong session, or leaves Back somewhere other than the task page; a failed run's
  sheet moves the page behind it or names a project, harness or model, which may not be the one that run used.
- A row jumps or snaps when a sheet's content changes, or the screen behind a sheet moves.
- An older bridge shows an empty or broken Scheduled page instead of the update row, or an older app fails to decode.
- An analytics event carries a prompt, name, project, harness or time, or fires for a refused save.

## Known Limitations

- A sleeping machine is not woken for a run; the missed-run policy decides what happens on wake.
- A crash between the history write and the send loses that run by design.
- A harness's own automatic compaction is not detected, so the bridge may compact once more. An external wake later
  than the window lands in a compacted session; on 5-minute cache routes that window is about 3 minutes.
- OpenCode declares compaction on request for v1 and v2 alike, so a v1 task offers and saves auto-compact on, and each
  run's compaction answers unsupported.
- Oh My Pi answers a session too small to compact with "Nothing to compact", which the bridge records as accepted: that
  run's one ask is spent and a run due first is held one pass (about 30 seconds). The next run gets its own ask.
- Run outcomes are not in analytics, and the desktop and editor-screen events are held (see Analytics).

## Harness Scope

See [Compaction on request](../HARNESS_CAPABILITIES.md#compaction-on-request) and
[Prompt-cache life](../HARNESS_CAPABILITIES.md#prompt-cache-life) for each harness's support and cache life.

## Related Coverage and Sources

- [Notifications](notifications.md), [Session archiving and deletion](session-archiving-and-deletion.md),
  [Permission auto-approval](permission-auto-approval.md), [Projects and sessions](projects-and-sessions.md),
  [Analytics](analytics.md), [Session creation and options](session-creation-and-options.md).
- Bridge: `ScheduledTaskService`, `ScheduledTaskRunService`, `ScheduledTaskCompactionService`,
  `ScheduledTaskActivityTracker`, `ScheduledTaskOccurrenceCalculator`, `ScheduledTaskTimerListener`,
  `ScheduledTaskFailurePushListener` and the `scheduled_task` handlers under `bridge/app`, with tests under
  `bridge/app/test/bridge/services/`, `routing/`, `persistence/`, `push/` and `drift/`.
- Shared: `scheduled_task.dart` and `scheduled_task_requests.dart` in `shared/sesori_shared`.
- Client: the scheduled-task API, repository and cubits in `client/module_core`, the views and sheets under
  `client/module_app_ui/lib/src/features/scheduled_tasks/`, and the task mark in `session_tile.dart`, with tests beside
  each.
- Plan: [.plan/completed/scheduled-tasks/PLAN.md](../../.plan/completed/scheduled-tasks/PLAN.md).
