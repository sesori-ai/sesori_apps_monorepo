# Step 19 — Share Mark unread and session actions with the phone

## Scope

- **The open phone session page gains the row's actions (D11, D20).**
  `SessionDetailBody` takes a nullable `menuEntriesBuilder`. With the floating
  glass bar it shows a dots button that opens the shared `PregoAnchorMenu`. The
  desktop page frame keeps its own toolbar menu and passes null.
- `SessionListActionDispatcher.sessionMenuEntries` replaces the
  `includeReadToggle` bool with the enum `SessionReadMenuEntry`: `toggle` for
  list rows, `markUnread` for an open page, `none` for the desktop toolbar,
  which has its own button. An open page is marked seen asynchronously, so a
  toggle there could offer Mark as read and send the wrong value.
- The phone page's dispatcher confirms delete with the sheet and returns to the
  session list after archive, delete and Mark as unread, through the existing
  `closeDeletedSessionRoute`. The read-only archived view offers no menu.
- No wire, database, string or analytics change.

## Deviations From The Plan

- The phone gets Mark as unread as a menu entry, not a separate bar button. The
  glass bar already carries Back, Changes and the busy indicator on a narrow
  screen.

## Review Follow-up

- The menu shows only for a root session, so a sub-agent page never adds its
  session to the project's list. `closeDeletedSessionRoute` moved into
  `core/routing`. Both came from review and were not re-measured.

## Automated Evidence

Measured checkpoint: commit `f76aa241689d1c9e2c2a356948b5c5232563860c` against
base `dfd7a9a66e17e8b3d39b506d1f9dc18586d23235`, Flutter 3.47.5 (Dart 3.13).
The commands ran on the same content before it was rebased onto the merged
step 18. No log files were kept; CI on the PR is the durable record.

- Size: 142 changed lines, 130 added and 12 deleted, across 8 files.
- `dart analyze --fatal-infos` in `module_app_ui`, `app` and `desktop`: clean.
- `flutter test --no-pub`: `app` 774, `module_app_ui` 398, `desktop` 273, all
  passing.
- `dart format --set-exit-if-changed` on the touched Dart files: unchanged.
