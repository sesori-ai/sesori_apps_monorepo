# Step 20 — Cleanup after the shared migration

## Scope

- `SessionListCubit.archiveSession` and its three cubit tests are deleted.
  Since step 18 every surface archives through `PendingSessionArchiveCubit`, so
  nothing in production called it. The session repository and API methods stay,
  because the pending-archive cubit uses them.
- A phone swipe test that asserted the deleted method was never called now
  asserts that no session entered the Undo window.
- No wire, database, string or analytics change, and no user-visible change.

## Deviations From The Plan

- The audit found nothing else to delete. Every shared input still differs
  between at least two hosts, no library file is unreferenced, and the unused
  strings that remain predate this plan, so they are out of scope here.

## Automated Evidence

Measured checkpoint: commit `a86b9242f51ed8ac64282bf218c6df7d3404bbd7` against
base `d9c7d5f8098553047e3d3195e3a0d8ca37a3e3a6`, Flutter 3.47.5 (Dart 3.13).
The commands ran on the same content before it was rebased onto the merged
step 19. No log files were kept; CI on the PR is the durable record.

- Size: 206 changed lines, 4 added and 202 deleted, across 3 files. 201 are
  tests.
- `dart analyze --fatal-infos` in `module_core` and `app`: clean.
- `flutter test --no-pub`: `module_core` session list cubit tests 65, the phone
  swipe test 9, all passing.
