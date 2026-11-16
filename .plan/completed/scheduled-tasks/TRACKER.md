# Scheduled Tasks — Tracker

This tracker records fixed planning metadata (PR titles, branches, size
targets, dependencies) and the guardrails every step must keep. It does not
mirror PR state; live status is on GitHub:
`gh pr list --state all --search "[scheduled-tasks]"`.

## Decisions In Force

- D1–D15 are the user's final decisions. P1–P13 are planning decisions from
  code evidence. See [PLAN](PLAN.md#user-decisions-final).
- Q1 is resolved as B (2026-11-15): the auto-compact quiet window is
  `min(cacheLife − 2 minutes, 25 minutes)`, 25 minutes when the plugin reports
  no cache life (P10).

## Guardrails

- Tasks belong to one bridge; no cross-computer list.
- No compaction timer: each tick compares `ScheduledTaskActivityTracker`'s
  last-activity instant and the run columns (P10). Never use
  `sessions.lastActivityAt` for this; it coalesces unattended activity.
- One owner each: `ScheduledTaskRunService.runDue()` (firing and compaction,
  under one lock) and `SessionRepository.getSessionQuietness` (quiet checks).
- `push/` never reads core repositories; pushes go through listeners.
- Compaction is only ever sent to an idle session; on ACP it must never cancel
  a turn (P9).
- A scheduled run never writes the user's remembered new-session picks (P7).
- At most once: write the run row and the next due time before sending (P6).
- User-visible entry points land only in step 9.
- Run marks use the meta line, not the time slot that
  `SessionScheduledResume` already uses.

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `plan/scheduled-tasks` | 🌱 [scheduled-tasks] Raise the plan [step 1/13] | ≤ 900 | — |
| 2 | `scheduled-tasks/contract` | ⚙️ [scheduled-tasks] Add the task contract and schedule times [step 2/13] | ≤ 1,500 authored, generated Freezed extra | 1 |
| 3.a | `scheduled-tasks/storage` | 🚧 [scheduled-tasks] Store tasks on the bridge [step 3.a/14] | ≤ 1,200 authored, generated Drift extra | 2 |
| 3.b | `scheduled-tasks/routes` | ⚙️ [scheduled-tasks] Serve the task routes [step 3.b/15] | ≤ 500 | 3.a |
| 4.a | `scheduled-tasks/session-quietness` | ⚙️ [scheduled-tasks] Read session quietness and start scheduled-run sessions [step 4.a/15] | ≤ 400 | 3.b |
| 4.b | `scheduled-tasks/new-session-runs` | 🚧 [scheduled-tasks] Run new-session tasks on the bridge [step 4.b/15] | ≤ 1,000 | 4.a |
| 5 | `scheduled-tasks/same-session-runs` | 🚧 [scheduled-tasks] Continue same-session tasks [step 5/17] | ≤ 700 | 4.b |
| 6 | `scheduled-tasks/marks-archive-pushes` | ⚙️ [scheduled-tasks] Mark task runs, archive old runs and limit pushes [step 6/18] | ≤ 900 | 5 |
| 7 | `scheduled-tasks/composer-reuse` | ⚙️ [scheduled-tasks] Let the new-session composer serve a task editor [step 7/14] | ≤ 900 | 1 |
| 8.a.1 | `scheduled-tasks/scheduled-page-core` | ⚙️ [scheduled-tasks] Add the scheduled-task client core [step 8.a.1/17] | ≤ 900 | 3.b, 4.b |
| 8.a.2 | `scheduled-tasks/scheduled-page` | ⚙️ [scheduled-tasks] Add the Scheduled page and task page [step 8.a.2/18] | ≤ 1,100 authored, generated l10n extra | 8.a.1 |
| 8.b | `scheduled-tasks/run-marks` | 🌿 [scheduled-tasks] Mark task runs in the session list and open task pushes [step 8.b/18] | ≤ 600 | 6, 8.a.2 |
| 9.a | `scheduled-tasks/new-task-core` | 🚧 [scheduled-tasks] Add the task editor core, time fields and device time zone [step 9.a/18] | ≤ 1,300 authored, generated Freezed extra | 4.b, 7, 8.a.2 |
| 9.b | `scheduled-tasks/new-task-screen` | 🚧 [scheduled-tasks] Add the New task screen [step 9.b/18] | ≤ 1,500 authored, generated l10n extra | 9.a |
| 10 | `scheduled-tasks/compact-on-request` | ⚙️ [scheduled-tasks] Compact sessions on request in every harness that can [step 10/14] | ≤ 1,200 | 1 |
| 11.a | `scheduled-tasks/cache-life` | ⚙️ [scheduled-tasks] Ask each harness for its prompt-cache life [step 11.a/20] | ≤ 500 | 10 |
| 11.b | `scheduled-tasks/auto-compact` | 🚧 [scheduled-tasks] Auto-compact same-session tasks on the bridge [step 11.b/20] | ≤ 900 | 5, 11.a |
| 11.c | `scheduled-tasks/auto-compact-switch` | 🌿 [scheduled-tasks] Add the auto-compact switch to the task editor [step 11.c/20] | ≤ 400 | 9.b |
| 12 | `scheduled-tasks/regression-docs` | 🌱 [scheduled-tasks] Write the regression docs [step 12/20] | ≤ 500 | 2–11.c |
| 13 | `scheduled-tasks/retire` | 🌱 [scheduled-tasks] Run the L3 regression and retire the plan [step 13/20] | ≤ 250 | 12 |

Step 2 and 3.a targets count authored lines; their Freezed and Drift output is
reported separately in the PR body (AGENTS.md generated-churn rule).
Steps 1 and 2 merged before step 3 split, so their titles keep the old total
of 13; 3.a, 7 and 10 merged before step 4 split and keep 14.
3.b, 4.a and 4.b keep the /15 in their published titles; 5 and 8.a.1 merged
at /17 before step 9 split, and keep it.
6, 8.a.2, 8.b, 9.a and 9.b merged at /18 before step 11 split, and keep it.

## L3 Regression Result (2026-11-16)

**Result: Partial, plan retired.** Every executable L3 cell passed, apart from the Blocked cells below. The findings
were fixed in their own PRs before retirement. Run on main `75984230e8`, with re-checks on the fixes. Live harnesses
ran only through the local 9router proxy, and the client cells ran on a headless iOS simulator (iPhone 17).

| Cell | Result | Evidence |
|---|---|---|
| CRUD, validation and pause through the routes | Passed | Create, edit, pause, resume and delete. Every refusal code was hit. A paused task stays paused after an edit (`scheduled_task_service_test.dart`) |
| One-off a few minutes ahead | Passed | Fired on time and left the list. No completion push |
| Missed runs across a bridge stop | Passed | Run when it's back fired once, marked late. Wait for the next time recorded missed, no fire |
| Overlap skip | Passed | Waiting on a permission: skipped. The working variant is covered by the run-service suite |
| Run now refusal and failure push | Passed after #2719 | Refused while a run works or waits. A Run now failure sends no push; a scheduled one pushes. A deleted project folder read `startFailed` until #2719 (F2) |
| At-most-once after a forced crash | Passed | SIGKILL 50 ms after the run row was written: no harness start and no second send after restart |
| Auto-archive | Passed | Pinned, busy and uncommitted-work sessions kept, five kept. The repository test covers pinned sessions never being counted |
| Completion suppression and can't-start push dispatch | Passed | No completion push for unattended runs or compactions. A user prompt pushes. Failure pushes collapse per task |
| Run firing, Claude Code 2.1.325 and Codex 0.169.0 | Passed after #2717 | New and same session, and an archived target replaced, on both. Codex first crashed the bridge when its app-server, having exited while idle, refused the next connect (F1). The re-check against `2796e0f564` passed: after an idle code-0 exit Codex went dormant, and Run now and a scheduled one-off each started a fresh app-server and got a reply, across 4 generations with no unhandled error. The refused-connect race never happened live; #2717's unit test covers it |
| Compaction on request | Partial | Passed: OpenCode v2 2.3.0, Pi 1.5.2, Hermes 0.21.5, Claude, Codex. OMP 18.20.2 answers "Nothing to compact" on a small session (known limitation). Blocked, needs a real account: Grok 1.0.30, DeepSeek 0.2.2, Cursor 2026.07.23. Blocked, not installed: Copilot, Antigravity, OpenCode v1. The plugin suites cover them |
| Auto-compact policy, Claude and Codex | Passed | One compaction after the window (Claude after 3 min, Codex after 25 min), a due run compacted first and held, a user prompt cancels |
| Scheduled page | Passed | Both headings and switches, pause and resume persisted |
| New task screen and its sheets | Passed | Nothing behind the sheets moved across 9 preset and 5 run-mode switches. Rows fold with size and fade |
| Save and edit | Passed | Stored values and the task page match |
| Run now on the phone | Passed | "Run started", then the "previous run is still going" refusal |
| Run marks | Passed | Repeat glyph and clock with the task name, plus screen-reader labels |
| Inert Auto-compact switch | Blocked | Every installed harness can compact. Antigravity was not installed, because that means accepting Google's terms. The 11.c widget tests cover the switch and its explanation |
| Update row against a v1.13.1 bridge | Passed | The Scheduled page, task page and editor show it, and a tap opens the update steps |

### Findings and their fixes

- **F1:** a refused Codex app-server connection crashed the bridge. Fixed in #2717 (`2796e0f564`).
- **F2:** a deleted project folder was reported as `startFailed`. Fixed in #2719 (`77b440c240`).
- **Zone label:** a paused task that never ran always named its zone, even in the device's zone. **Editor:** the update row had doubled padding and the title wasn't centred. Both fixed in #2718 (`7aff573534`).
- **F4, Hermes:** the reply showed twice. Fixed in #2720 (`d48566f823`).
- **OMP:** "Nothing to compact" counts as accepted. Spending one run's ask is low damage, so it is recorded as a known limitation in the regression doc.
- **Decisions for the next scheduled-tasks review page:**
  - whether "Every few hours" should show its start time;
  - whether Run now should be refused for 30 seconds after a short run.
