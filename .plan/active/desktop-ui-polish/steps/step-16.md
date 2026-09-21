# Step 16 — Show the phone session list as one timeline

## Scope

- **One timeline everywhere (D10, D20).** A running session is a row of Today
  on the phone too, whatever its stored time, and leads that section. The row's
  rotating sparkle already says it is running, so no Running heading remains.
- `SessionListGrouping` had one remaining meaning once every list uses the
  timeline, so the enum and its argument are deleted from `SessionListContent`
  and its four hosts. The plan listed that deletion under step 20; it is a few
  lines and belongs with the change that made it obsolete.
- No string, wire, database or analytics change. `sessionListRunning` is still
  used by the session row.

## Deviations From The Plan

- The grouping switch is removed here rather than in step 20.
- The step came out far below its 500-line target because the desktop work in
  step 9 had already built the timeline inside the shared list.

## Automated Evidence

Measured checkpoint: commit `402f33f2d427a1ec164386787bd99c7ef21f19d1` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/module_app_ui
flutter test --no-pub
dart analyze --fatal-infos
cd ../app
flutter test --no-pub
dart analyze --fatal-infos
cd ../desktop
flutter test --no-pub
dart analyze --fatal-infos
```

- `module_app_ui`: 394 cases pass. The list cases prove running rows lead
  Today with no Running heading, including a session running since yesterday.
- `app`: 776 cases pass. `desktop`: 276 cases pass.
- All three analyzers report no issues.
- `architecture-implementation-review` was not run. The step deletes the
  internal `SessionListGrouping` enum and its argument on `SessionListContent`;
  it changes no public, wire or persisted contract and moves no ownership or
  dependency.

## Size

**54 changed lines (15 additions and 39 deletions) across 8 files** at the
measured checkpoint. Of those lines, 12 are tests, 15 are regression documents
and the remaining 27 are production source. Reproduce from the root:

```sh
git diff --numstat 051170c2903c6ef0078603d977cd1fae3875cc67 402f33f2d427a1ec164386787bd99c7ef21f19d1
```

The step target was 500; the repository soft cap is 1,500. This file and the
tracker row come on top.

## Regression Documents

`projects-and-sessions.md` describes the single timeline, its coverage note and
its failure signal. `desktop-cockpit-shell.md` no longer says the phone keeps a
Running section.
