# Step 5 — Keep The Reader's Turn In Place When Turns Fold Or Unfold

Branch `turn-navigation/keep-place`. Architecture 4.

## Plan Claims Checked

- The termination argument holds on Flutter 3.47.5. `RenderSliverList` lays
  out every row between its first child and the scroll offset in one pass,
  either way, so only an overshoot could skip the target.
- A switch moves built rows by key and drops their offsets. Unfolding leaves
  newer rows built, so the search runs from below. Folding far up leaves only
  the oldest row built, so it runs from above.
- Through prompts of 828 px and answers of 680 px in a 600 px viewport, the
  search made 6 jumps of 1,360–1,508 px from below and 5 of 880 px from above,
  then one settling jump. Every jump moved the same way, and the prompt
  settled within 1 px.
- `scheduleJumpToEdge()` cannot pull the list back: the jump's own scroll end
  runs the tracker's reattach check, which detaches beyond 20 px.
- "While following, a switch keeps following" covers the bar and shortcuts. A
  stub tap anchors its turn even while following (D9), and the list detaches.

## Scope Delivered

- `TranscriptRowReporter`, keyed like its row, registers the row's context in
  the list's private map from `initState` to `deactivate`.
- The build runs `TranscriptTurnBuilder` in both modes. `rowTurns` maps each
  message row to its turn, replacing step 4's `foldedTurns` and `turnStubs`.
- A fold switch while detached with no anchor pending holds the top-edge turn
  from `didUpdateWidget`. `_stepAnchor` restores the one pending anchor after
  each frame, one jump a frame.
- `TranscriptTurnStub` is a `TextButton`. Its tap unfolds through
  `onTranscriptFoldedChanged`, which `SessionDetailLoadedView` binds to
  `setTranscriptFolded`. The unfolded branch of `_onJumpToTurn` has no caller
  until steps 8 and 9.
- No control, analytics event or regression document: users see no change.

## Deviation

- The helper does not call `detach()`: removing it failed no test. A landing
  within 20 px of the latest edge follows again and ends the anchor, as a
  manual scroll ending there would. PLAN.md's Architecture 4 says so.

Size: under the 500-line target. Production code is 267 lines, tests 160, and
docs the rest.

## Automated Evidence

Toolchain: Dart 3.13.4 from Flutter 3.47.5. `dart analyze --fatal-infos` is
clean in `module_app_ui`. `dart format -l 120` changes no touched file.

| Command | Result |
|---|---|
| `flutter test test/features/session_detail/` in `client/module_app_ui` | 312 passed (6 new) |
| A `detach()` after each jump | no test fails, so it was removed |
| The search jumps 12 viewports whatever the rows | both search tests never settle |

## Review

Pending.

## Manual

None: no control folds the transcript yet, so no stub can be reached.
