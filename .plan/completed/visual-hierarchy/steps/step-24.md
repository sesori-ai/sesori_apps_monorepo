# Step 24 — Folder browser

## What changed

- The add-project sheet and dialog are titled "Add project" beside the close
  button (AP1): 18 bold in the phone sheet, the desktop dialog frame's 16
  bold (D7).
- A tappable breadcrumb replaces the "~ Home" and "/ Root" chips, the up
  arrow and the "../<path>" line (AP2). Segments read 14 secondary with
  tertiary chevrons; the browsed folder is last, in bold, and not tappable.
  The folders from the root down to the starting folder collapse into one
  Home segment. A deep path scrolls sideways and starts at its end.
- A folder without subfolders reads "No folders here" with a second line
  (AP3).
- The add button reads "Add <folder>" (AP5). `hostPathBasename` in
  `project_tile.dart` names the folder for both separator styles and now
  also backs `projectDirectoryBasename`.
- Removed strings: `addAsNewProject`, `emptyDirectory`, `parentDirectory`,
  `folderPickerRoot`. `folderPickerHome` now reads "Home".

## Deviations

- **The root stays ahead of Home.** The plan puts Home first. With the Home
  and Root chips gone, that would leave no way to reach the root from inside
  Home, which works today. The breadcrumb therefore reads "/ › Home ›
  projects"; the root segment shows the root's own path ("/", or "C:\" on
  Windows).
- **Empty-state wording.** The plan says the second line should say that the
  folder holds only files. The bridge lists folders only and does not report
  files, and a folder just made with Create new folder is truly empty, so
  that sentence would be wrong there. The line reads "Only folders are
  listed, so any files in it stay hidden."

## Verification

- `client/module_app_ui` `test/features/project_list/` (22 tests): title,
  breadcrumb segments and taps (Home, root, folders outside Home), the add
  button label, the empty state, and the stale-listing guard, now stepping
  back through the breadcrumb.
- `client/app` `connected_empty_view_test` and `client/desktop`
  `desktop_cockpit_shell_test`.
- `dart analyze --fatal-infos` clean in module_app_ui and app.
- Before and after renders in the PR body for phone (home, empty folder) and
  desktop (home), all with fixture data.
