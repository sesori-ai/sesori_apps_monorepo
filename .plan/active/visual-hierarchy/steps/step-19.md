# Step 19 — Search on the phone

## What changed

- `module_core` gains `matchTitles` (`utils/title_matcher.dart`): the items
  whose title holds every whitespace-separated query word, ignoring case, in
  their original order, with each word's first match as sorted, merged
  ranges. A blank query keeps everything. Step 20's palette reuses it for
  highlights.
- `module_app_ui` gains `ListSearchField`, a filled search field with a clear
  button that reports each edit; the list owns the query in widget state.
- Projects: the field sits under the catalog scan row once projects exist. It
  narrows project names and Activity's session titles; nothing matching reads
  "No matches".
- Session lists: `SessionListFilteredContent` takes `searchable` (phone
  scaffold and split pane on, desktop project page off) and narrows both the
  list and the chip counts; `SessionListContent` takes the `query`.
- The Archived page is not searchable in this step.

## Verification

- `client/module_core` `test/utils/title_matcher_test.dart` passes.
- `client/module_app_ui` `test/features/session_list` passes, including the
  new filter, No matches and clear test; `client/app` `test/features/project_list`
  and `test/features/session_list` pass with the new projects search test;
  `client/desktop` `test/features/sessions` passes.
- `dart analyze --fatal-infos` clean in `client/module_core`,
  `client/module_app_ui`, `client/app` and `client/desktop` (lib).
- Light and dark Projects renders checked (idle, typing, no matches); the
  first render's field fill matched the page and moved to `bgTertiary`.
- Architecture implementation review: approved in the first round.
