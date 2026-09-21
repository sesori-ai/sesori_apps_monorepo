# Step 18 — Archive with Undo on the phone

## Scope

- **One archive flow everywhere (D13, D20).** `PendingSessionArchiveCubit` and
  its state move unchanged from `module_desktop_core` to `sesori_dart_core`.
  The alerts move to `sesori_app_ui` as `PendingArchiveAlerts`.
- The phone provides the cubit above its router, so an Undo window survives
  leaving the project, and hosts the alerts there through the root navigator
  key, as `SseToastListener` already does. The desktop keeps hosting them under
  its shell route.
- `SessionListActionDispatcher` always archives through that cubit, asking
  first only for a running session, then tells `onSessionArchived`. The sealed
  `SessionCleanupFlow` becomes the enum `SessionDeleteConfirmation`, because
  only delete still differs: a sheet on the phone, a compact alert on desktop.
- `SessionListFilteredContent` hides a session inside its Undo window and
  refreshes the list on a committed archive. That logic moved from the desktop
  page, so the hosts no longer pass hidden ids.
- Deleted with the flow they served: the phone's archive confirmation sheet,
  the force-archive branch of the force dialog, four strings, and the phone
  tests that only exercised a replica of that sheet.
- No wire, database or analytics change.

## Deviations From The Plan

- `SessionListCubit.archiveSession` is now unused by production code. Its
  removal, with its tests, is left to step 20 to keep this step near its size
  target.
- The step measures 983 lines against a 900 target. 581 of them are tests,
  mostly deletions of the replica sheet tests and provider additions in the
  phone harnesses.

## Automated Evidence

Measured checkpoint: commit `d289248261d4b56b43ced6a0f9f04e266687ae1c` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. The
commands ran on the same content before it was squashed and rebased onto the
merged step 17, which it already contained. No log files were kept; CI on the
PR is the durable record. This file, the tracker row and the plan note were
added afterwards as documentation only and were not re-measured.

```sh
cd client/module_core && flutter test --no-pub && dart analyze --fatal-infos
cd ../module_app_ui && flutter test --no-pub && dart analyze --fatal-infos
cd ../app && flutter test --no-pub && dart analyze --fatal-infos
cd ../desktop && flutter test --no-pub && dart analyze --fatal-infos
cd ../module_desktop_core && flutter test --no-pub && dart analyze --fatal-infos
```

- `module_core`: 1,836 cases pass, including the moved cubit cases.
- `module_app_ui`: 398 cases pass. New cases prove the alerts work when hosted
  above a router, and that archive enters the Undo window without asking
  except for a running session.
- `app`: 773 cases pass. The swipe pill, the full swipe and the row menu hide
  the row at once with no sheet, and Undo brings it back.
- `desktop`: 273 cases pass. All five analyzers report no issues.
- `module_desktop_core`: 334 cases pass and two `desktop_instance_api_test`
  process-lock cases failed in the full local run while a locally built
  desktop app was running on the same machine. The file passes when run alone,
  and this step does not touch that code.
- `architecture-implementation-review` ran once through a sub-agent on the
  step's commit range and returned APPROVED with no findings.

## Size

**983 changed lines (332 additions and 651 deletions) across 39 files** at the
measured checkpoint, with renames detected. Of those lines, 581 are tests, 24
are regression documents, 37 are generated localisations and the remaining
341 are production source. Reproduce from the root:

```sh
git diff -M --numstat cd48a8fcdabcb9e997ea822d71dc327f04507ec2 d289248261d4b56b43ced6a0f9f04e266687ae1c
```

The step target was 900; the repository soft cap is 1,500.

## Regression Documents

`session-archiving-and-deletion.md` describes archive with Undo on both
surfaces, the app-owned window, and the phone's remaining delete sheet.
`popup-alerts.md` no longer calls the Archived alert desktop-only.
