# Step 46 — Tool-group motion

Branch `visual-hierarchy/group-motion`. Client only, `module_app_ui`, shared by
both shells. No new cubit state.

## What changed

- `TranscriptPresence` eases one transcript row in (height and fade) or folds
  it away (height, fade and a short upward slide). A settled row has no
  controller, ticker or clip; the controller exists only once the row moves.
- `TranscriptPresenceColumn` keeps a leaving row in place, as it last looked,
  until it has folded away, and eases in rows that join after its first
  build. It renders the group (summary and live rows), the group's open panel,
  an assistant message's blocks and the thinking tail. The "Working…" row uses
  it too, and its list row now always exists (empty while idle), so it eases in
  and out when work starts and ends, not only when a step replaces it.
- The message list eases in a new agent, error or retry row that joins at the
  newest edge while the reader follows. Prompt and user rows appear at once, as
  before; nothing animates while the reader is scrolled away, and the rows
  caught up on reattach do not animate.
- The retry card's row always exists too, so the card folds away when the retry
  error clears instead of vanishing in one frame.
- `TranscriptRollingLine` renders the summary's counts and its failure count.
  At rest it is the same single ellipsizing `Text`. On a change it rolls only
  what differs, word by word: "read 1 file" to "read 2 files" rolls the digit
  and the new "s"; a new kind or the first failure wipes in with a fade; the
  line's width eases, so the failure count after it moves instead of jumping.
- One motion token pair, `transcriptMotionDuration` (200 ms, step 2's value)
  and ease-out curves, drives the fold, the entries, the roll and the existing
  disclosure. Reduced motion makes every change instant.

## Deviations from the plan

- The plan named no user-row behaviour; prompts and user messages keep
  appearing at once, because the send must show immediately and their height
  changes already ease.
- A summary segment that disappears (no normal flow produces one) drops
  without animation.

## Verification

- `module_app_ui`: `test/features/session_detail` and `test/widgets` passed,
  including the new tests: the rolling line rolls only what changed and eases
  its width, a new segment wipes in, reduced motion is instant; a finished live
  row folds while the count rolls and ends folded; a new live row and a first
  summary ease in; reduced motion folds at once; a reader pinned at the bottom
  stays pinned, with no jump button, through every frame of a fold.
- `app` `test/features/session_detail` and the full `desktop` suite passed.
- `dart analyze --fatal-infos` is clean in `module_app_ui`.
- Fixture-only GIFs of a tool folding into its group with the count rolling,
  phone and desktop, dark theme, are in the PR.
