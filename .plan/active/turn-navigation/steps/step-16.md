# Step 16 — Search The Loaded Prompts

Branch `turn-navigation/prompts-search`. Architecture 15 (search, D30, D39).
It ships as PR step 17/19, because the prompt numbers and times (step 15) took
their own PR number earlier in the series.

## Plan Claims Checked

- `ListSearchField` reports every edit without a debounce, and each entry
  already carries `fullText`. So the filter is a synchronous pass over the
  loaded entries, with no index and no bridge call.
- `SessionDetailLoaded` already exposes `olderMessagesCursor` and
  `isLoadingOlderMessages`, and the cubit exposes `loadOlderMessages`. The
  control needs no new cubit or state.
- Every row, grown row, day header and the control have fixed extents, so the
  view can lay out the whole list arithmetically. The same arithmetic keeps the
  reader's row in place when a page is prepended.

## Scope Delivered

- The header's title row is now `ListSearchField` plus the close button, capped
  to the list's width on the desktop. `ListSearchField` gains `autofocus` and
  `padding`; its two existing callers pass their old values.
- The search is case-insensitive over `fullText` (`prompt_search.dart`). Each
  kept row grows by one excerpt line: 24 characters before the first match and
  80 after, with whitespace collapsed and the match highlighted. Day headers
  keep the original contiguous runs and fold away with their last row. The
  last sliver reads "{n} matches in the prompts loaded so far".
- "Load earlier prompts" is the first sliver. It shows while
  `olderMessagesCursor != null`, is disabled while loading, and calls
  `loadOlderMessages`. After a load, `SessionDetailBody` refreshes the screen's
  prompt snapshot. Other transcript changes still leave the snapshot alone.
- `didUpdateWidget` corrects the offset by the net extent change above the
  reader's row, covering both prepended rows and the control disappearing.

## Deviations

- The plan budgets one `String` of view state. The feel brief asked for
  animated filtering with the reader's row held still, which also needs:
  - an `AnimationController`;
  - the change in progress (the starting heights and the previous pattern,
    whose excerpts stay on rows that are folding away);
  - the held row;
  - the last build's extents.

  All of this is view-local and has no new class or ownership, so no
  architecture review was run.
- The row being read is the tinted row while it is on screen, otherwise the
  top row. During a change, the kept row nearest after it (or else before it)
  moves from its own y to the reader's y, so clearing a search leaves the match
  that was being read in place. A list shorter than the screen settles against
  its ends. So does a last page smaller than the control when it is loaded from
  the very top.
- While searching, every kept row grows, including one whose match is already
  on its first line. This gives every row the same fixed extent.
- Escape closes the screen even while typing, and the query is not kept.
  Desktop autofocuses the field. Phone does not, so opening the screen raises
  no keyboard.
- An empty list with earlier pages shows the control instead of the empty text.
- Search is not tracked in analytics, as the plan says.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `module_app_ui` and `client/app`.
- These tests pass:
  - `module_app_ui` session prompts (14), session detail, session list,
    project list and widgets (551);
  - `client/app` session detail body (150).
- The new view tests cover:
  - filtering as the query is typed and clearing, with the reader's row held
    at the same y on every frame of the fold;
  - the grown row and its highlighted match;
  - day headers only for days with a match;
  - the match counts;
  - the control's place and its disabled state;
  - earlier prompts joining the filter with the reader's row still, including
    when the control disappears;
  - Escape and the desktop's focused field.
- The body test loads earlier prompts through the cubit, and the rows stay put.
- Before and after fixture renders and a phone GIF are on `pr-media` under
  `turn-navigation/prompts-search/`.
- Not run: a real device or a live bridge.
