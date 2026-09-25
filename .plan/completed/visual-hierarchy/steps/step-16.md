# Step 16 — File list in Changes

Split in two: 16.a adds the shared file list, which is the whole phone change;
16.b gives the desktop its toolbar, list on the left and one diff on the right.

## 16.a What changed

- With more than one file, Changes opens with a grouped list of every file:
  status letter (A, D, M), name, folder, and nonzero +/− counts.
- A tap scrolls that file's diff to the top and reopens it if collapsed. Each
  file's sliver group carries the scroll key: offscreen pinned headers are
  never built, but the group is always laid out. Diff bodies are lazy lists
  whose heights are estimated until built, so the reveal runs once more after
  the jump builds them.
- The status letter and counts are shared by the list and the diff headers.

## 16.a Verification

- `client/module_app_ui` and `client/app`: `dart analyze --fatal-infos` is clean.
- `client/app` `test/features/session_diffs` passes. A new test checks the
  list's folders, status and counts, a jump to a file far below, and that a
  jump reopens a collapsed file. The collapse tests find headers inside the
  pinned headers, since the list repeats each name.
- `client/module_app_ui` `test/features/session_diffs` passes.
- Rendered the phone page in light and dark before and after.

## 16.b What changed

- The shared diff view takes a sealed chrome: the phone's glass bar with a
  pinned header per file, or a split under the shell's own header.
- The desktop Changes page uses the page toolbar (project breadcrumb, title,
  file count and totals) over the file list on the left and the selected
  file's path and diff on the right. The row fill matches the sidebar's.
- The page has no Back of its own: Cmd/Ctrl+[ returns to the session and the
  breadcrumb opens the project, as on the session page.

## 16.b Verification

- `client/module_app_ui`, `client/desktop` and `client/app`:
  `dart analyze --fatal-infos` is clean.
- `client/module_app_ui` `test/features/session_diffs` passes, including a new
  split test: the first file shows, and a tap on another shows only its diff.
  A test cubit must hold a decoded response's list, because freezed rewraps a
  plain list on every read and the view would recompute forever.
- `client/desktop` `test/core/routing/desktop_router_test.dart` passes; the
  diffs route now checks the breadcrumb instead of Back.
- `client/app` `test/features/session_diffs` passes.
- Rendered the desktop page in light and dark, stacked (before) and split.
