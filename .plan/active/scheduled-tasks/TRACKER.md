# Scheduled Tasks — Tracker

This tracker records fixed planning metadata (PR titles, branches, size
targets, dependencies) and the guardrails every step must keep. It does not
mirror PR state; live status is on GitHub:
`gh pr list --state all --search "[scheduled-tasks]"`.

## Decisions In Force

- D1–D15 are the user's final decisions. P1–P13 are planning decisions from
  code evidence. See [PLAN](PLAN.md#user-decisions-final).
- Q1 (auto-compact quiet window) is open; step 11 uses the provisional
  25-minute default unless the answer changes it.

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
| 3 | `scheduled-tasks/storage` | 🚧 [scheduled-tasks] Store tasks on the bridge and serve the task routes [step 3/13] | ≤ 1,200 authored, generated Drift extra | 2 |
| 4 | `scheduled-tasks/new-session-runs` | 🚧 [scheduled-tasks] Run new-session tasks on the bridge [step 4/13] | ≤ 1,000 | 3 |
| 5 | `scheduled-tasks/same-session-runs` | 🚧 [scheduled-tasks] Continue same-session tasks [step 5/13] | ≤ 700 | 4 |
| 6 | `scheduled-tasks/marks-archive-pushes` | ⚙️ [scheduled-tasks] Mark task runs, archive old runs and limit pushes [step 6/13] | ≤ 900 | 5 |
| 7 | `scheduled-tasks/composer-reuse` | ⚙️ [scheduled-tasks] Let the new-session composer serve a task editor [step 7/13] | ≤ 900 | 1 |
| 8 | `scheduled-tasks/scheduled-page` | ⚙️ [scheduled-tasks] Add the Scheduled page and task page [step 8/13] | ≤ 1,500 (split 8.a page / 8.b marks if over) | 2, 3, 4, 6 |
| 9 | `scheduled-tasks/new-task-screen` | 🚧 [scheduled-tasks] Add the New task screen [step 9/13] | ≤ 1,500 (split 9.a fields / 9.b screen if over) | 4, 7, 8 |
| 10 | `scheduled-tasks/compact-on-request` | ⚙️ [scheduled-tasks] Compact sessions on request in every harness that can [step 10/13] | ≤ 1,200 | 1 |
| 11 | `scheduled-tasks/auto-compact` | 🚧 [scheduled-tasks] Auto-compact same-session tasks [step 11/13] | ≤ 800 | 5, 9, 10 |
| 12 | `scheduled-tasks/regression-docs` | 🌱 [scheduled-tasks] Write the regression docs [step 12/13] | ≤ 500 | 2–11 |
| 13 | `scheduled-tasks/retire` | 🌱 [scheduled-tasks] Run the L3 regression and retire the plan [step 13/13] | ≤ 250 | 12 |

Step 2 and 3 targets count authored lines; their Freezed and Drift output is
reported separately in the PR body (AGENTS.md generated-churn rule).
