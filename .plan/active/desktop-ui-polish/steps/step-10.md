# Step 10 — Project page filter chips and hover actions

## Scope

- **Filter chips (D10).** Above the active list the desktop project page shows
  **All · N**, **Running · N** and **Unread · N**. The counts come from the
  loaded list through the existing `isSessionRunning` and `isSessionUnseen`
  resolvers, so they are exact. The selected chip is a value local to the
  page's state; choosing one makes no request and touches no cubit state. The
  chips hide while Archived is on, which always shows every archived session,
  and while the project has no session. A filter that leaves nothing shows a
  short message instead of the first-run empty state.
- **Shared list.** `SessionListContent` takes the required closed
  `SessionListQuickFilter` (`all`, `running`, `unread`) and narrows the rows and
  their date headings to it. The phone's three call sites pass `all` and are
  unchanged.
- **Hover actions.** In pointer mode, hovering a `SessionTile` or moving
  keyboard focus into it swaps the trailing slot for Mark read/unread and
  Archive icon buttons wired to the row's existing handlers. They sit inside
  the title's line box, so revealing them never changes the row's height. An
  archived row offers no Archive, the rule its menu follows. The buttons are
  excluded from semantics: merged into the row they would fight its own tap
  action, and the row's menu stays the assistive path.
- Four new strings (three chip labels with a count, one filtered-empty
  message). No wire, database or analytics change.

## Automated Evidence

Measured checkpoint: commit `7054dd9ebd13784d2a0006afde24cb84316ad11d` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/module_app_ui
flutter test --no-pub
flutter analyze --no-pub
cd ../app
flutter test --no-pub
flutter analyze --no-pub
cd ../desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `module_app_ui`: 391 cases pass. New cases prove hovering reveals both
  actions at an unchanged row height and that they call the row's handlers,
  and that keyboard focus reveals them with no Archive on an archived row.
- `desktop`: 267 cases pass. The new page case proves the chip counts, local
  narrowing through the shared list, the filtered-empty message, and that
  Archived hides the chips and shows every session.
- `app`: 774 cases pass. All three analyzers report no issues.
- From `client/module_app_ui`, `flutter gen-l10n` exited 0 and regenerated the
  two localisation files; nothing generated was edited by hand.
- Appearance was checked once in rendered output with the packaged fonts, in
  light and dark. The first render showed the hovered row growing; the buttons
  were then fitted to the title line and the height assertion added.
- No architecture review was run: the step adds one closed enum parameter in
  the shape step 9's review approved, and widget-local presentation.

## Size

**305 changed lines (289 additions and 16 deletions) across 13 files** at the
measured checkpoint; 42 are generated localisation lines, 71 are tests and 8
the regression document. Reproduce from the root:

```sh
git diff --numstat "$(git merge-base origin/main 7054dd9ebd13784d2a0006afde24cb84316ad11d)" 7054dd9ebd13784d2a0006afde24cb84316ad11d
```

The step target was 500; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` gains the chips' and hover actions' required
behaviour and their automated coverage.
