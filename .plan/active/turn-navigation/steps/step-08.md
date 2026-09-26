# Step 8 — Pin The Current Turn's Prompt While Reading It

Branch `turn-navigation/sticky-prompt`. Architecture 6.

## Plan Claims Checked

- The list's `_topEdgeTurn` (step 5) already finds the turn at the top edge
  from the built rows, so the sticky pass reuses it and needs no new scan.
- `_holdTurn`'s anchor search (step 5) already reaches an unbuilt row and
  detaches the list on each jump (step 7 fix), so the jump reuses it: the
  jump is a hold of the opener row at 0 px below the top edge. A jump while
  following stops following, consistent with the user decisions for folds
  and pinches.
- `TranscriptTurns.promptTurnFor` (step 2) gives the overlay the opener
  without another lookup.

## Scope Delivered

- `TranscriptStickyPosition` (`transcript_sticky_position.dart`): the pinned
  opener's id and how far below the top edge the next turn's opener starts.
- `TranscriptStickyPromptOverlay` (`transcript_sticky_prompt_overlay.dart`):
  the prompt in the user bubble's style, clamped to three lines, on a band of
  the page background that fades out below it (the round-3 R5 mock). With no
  text it shows the first attachment's name, or "Attachment". While pinned it
  is one semantics button labelled with its text, hinted "Jump to this
  prompt", whose tap action jumps.
- The list publishes the value after every frame that built or scrolled it
  (one coalesced post-frame pass) and places the overlay at `topInset` inside
  its horizontal insets. It is null while folded, over a partial or preamble
  segment, and while the opener is below the edge.
- `onJumpToTurn` is the list's private `_jumpToTurn`: unfolded it puts the
  opener at the top edge; folded it unfolds and holds that turn (D9), for
  step 9's index.
- The band is hit-test translucent over an ignored subtree, so a drag or a
  wheel that starts on it still scrolls the rows beneath; its tap recognizer
  enters the arena first, so a tap goes to the prompt.
- The regression document covers the sticky prompt.

## Deviations

- The value carries `nextOpenerTop` instead of a precomputed `pushOffset`.
  The band's height is known only at its own layout, so the overlay clamps
  the push to [−height, 0] in a `FlowDelegate` at paint. The list would
  otherwise read the band's height from the previous frame, which is stale
  on the frame a pinned prompt first appears or changes.
- The overlay takes no `topInset`: the list positions it.
- The pinned prompt shows the prompt's Markdown source as plain text, so a
  three-line clamp is exact. Recorded as a known limitation.

## Automated Evidence

Toolchain: Dart 3.13.4 from Flutter 3.47.5. `dart analyze --fatal-infos` is
clean in `module_app_ui`. `dart format -l 120` leaves the touched files
unchanged.

| Command | Result |
|---|---|
| `flutter test test/features/session_detail/` in `client/module_app_ui` | 361 passed |
| `flutter test test/features/session_detail/` in `client/app` | 168 passed |
| `flutter test test/features/sessions/desktop_session_detail_screen_test.dart` in `client/desktop` | 13 passed |

New tests in `session_detail_message_list_test.dart`, group "the sticky
prompt":

- the prompt pins once it leaves the top edge, and the earlier turn's prompt
  pins while this one is still on screen;
- the next prompt pushes it out: at half its height, its top sits half its
  height above the edge and its bottom on the next prompt;
- it hides while folded, and over automation before the first prompt;
- a 40-line prompt clamps to three lines;
- a tap puts the prompt at the top edge and stops following;
- while pinned over a turn whose prompt row is not built, it is a labelled
  button with the hint, and its semantics tap action reaches the prompt.

Size: about 480 changed lines against the 650-line target, including the
generated localization files and about 45 lines of re-indentation from the
new `Stack`.

## Review

`architecture-implementation-review` over `origin/main...HEAD` approved with no
findings, and accepted both deviations. It noted outside its scope that
`_textOf` repeats the text join of `user_message_card.dart` and the filename
switch of `file_part_widget.dart`; a shared helper waits for a third caller.

## Visuals

Rendered through a throwaway widget test (not committed) with fixture text,
before (origin/main) and after, on `pr-media` under
`turn-navigation/sticky-prompt/`.

## Manual

- **Pending, for the user:** a real iPhone scroll through a long turn for
  visible lag, and an Android smoke check. No tool here can drive a device:
  the `agent-device` server did not connect, and the user's bridge and
  desktop app were left alone.
