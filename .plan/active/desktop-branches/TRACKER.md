# Desktop branches tracker

Status values: Pending, In progress, PR open, Merged, Blocked, Dropped.

| Step | Status | PR | Notes |
| --- | --- | --- | --- |
| 1 Raise the plan | PR open | #2463 | |
| 2 Fold the subtle desktop differences | Pending | | Waits for #2460. Record each item's measured before and after; list dropped items here for the metrics phase. |
| 3 Fold the transcript and needs-you card looks | Pending | | Waits for step 2 (bash label colour follows item 2.6). |
| 4 Fold the settings, alert, diff and picker looks | Pending | | Waits for step 2. Can run in parallel with step 3. |
| 5 Flag new interaction-mode reads | Pending | | Waits for steps 3 and 4. Record whether `unnecessary_ignore` reports stale plugin ignores. |
| 6 Reconcile regression docs | Pending | | |
| 7 Run the verification matrix and retire the plan | Pending | | |

## Outside the series

| Work | State | Notes |
| --- | --- | --- |
| #2460 Drop dead and no-op desktop checks | PR open | Precursor. The phone "Waiting" amber is not in its diff at `da699077fb`; if it merges without it, item 2.15 folds it. |
| `desktop-text-size` | Local branch, no PR | Shares `prego_anchor_menu.dart` with step 4 (another hunk). |

## Read counts

| Point | Reads | Files |
| --- | --- | --- |
| `origin/main` `478ea1c15e` | 105 | 46 |
| After #2460 | 101 | 44 |
| After step 4 (planned) | about 71 | about 35 |
