# Step 9/13: Keep owed messages when the first load finds the harness blocked

#1873 (step 8/11) merged at 4f9d820723 before its eight Codex findings on
38799d5fa0 were answered. Fixing them measured about 1,100 changed lines, so
they land in two PRs: this one (finding 2) and 10/13 (the composer findings).

| # | Finding | Outcome |
|---|---|---|
| 1 | Option pills open while sending | 10/13 |
| 2 | Owed messages vanish on a harness-blocked first load | Fixed here: `SessionDetailHarnessUnavailable` carries the owed messages as `SessionDetailFailed` does. The body renders them under the blocked notice with their Cancel and Remove actions, and names the harness |
| 3 | Caret and composing range lost at handoff | 10/13 |
| 4 | Swap while an image pick or paste is pending | 10/13 |
| 5 | Voice policy in the view | 10/13 |
| 6 | Two send intents | 10/13 |
| 7 | Harness name lost after a failed first load | Declined: `SessionDetailFailed` holds no plugin id, and the damage is cosmetic ("Sending" instead of "Sending to `<harness>`"). The blocked state does name the harness |
| 8 | Staged images lost when the first load is blocked | Declined: this needs the harness to block seconds after a successful create. Keeping the images would mean holding composer attachments in the cubit for every session, and N2 already accepts losing them there |

## Evidence

- `module_core` session-detail tests, including a new bridge-queue test: a
  harness-blocked first load keeps the queued send and the launch's follow-up,
  and Cancel still works.
- `app` session-detail body tests, including a new test: the owed messages
  appear under the blocked notice, and Cancel and Remove reach the cubit.
- `dart analyze --fatal-infos` is clean on `module_core`, `module_app_ui` and
  `app`.
