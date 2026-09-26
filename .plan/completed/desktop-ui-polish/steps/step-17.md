# Step 17 — Share the session filter chips with the phone

## Scope

- **One chip row everywhere (D10, D20).** The All / Running / Unread chips,
  their counts and the filtered-empty message move from the desktop project
  page into `SessionListFilteredContent` in `module_app_ui`. It wraps
  `SessionListContent` as one sliver and owns the chosen chip.
- The desktop project page, the phone session list and the split-pane list
  all host it, so the phone now shows the chips. The archived view still uses
  `SessionListContent` directly, because Archived shows everything it has.
- The strings become `sessionListFilter*` and the keys
  `session-list-filter-<name>`; the wording is unchanged.
- No wire, database or analytics change.

## Deviations From The Plan

- None. The step also corrects one sentence of the step 16 record, as promised
  in review on PR #1582.

## Automated Evidence

Measured checkpoint: commit `3ec37404f77d963e7d8315b1e03aae900a5d4954` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. The
commands ran on the same tree before it was rebased onto the merged step 16,
whose content it already contained. Every command exited 0. No log files were
kept; CI on the PR is the durable record. This file and the tracker row were
added afterwards as documentation only and were not re-measured.

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

- `module_app_ui`: 395 cases pass. A new pane case proves the chips count the
  list, narrow it and show the filtered-empty message.
- `app`: 776 cases pass. `desktop`: 276 cases pass, including the existing chip
  cases against the shared widget.
- All three analyzers report no issues.
- A throwaway render of the real phone list, light and dark, was inspected by
  eye and not committed.
- `architecture-implementation-review` was not run. The step extracts one
  presentation widget inside the package that already owned the list; it
  changes no public, wire or persisted contract and no dependency direction.

## Size

**271 changed lines (178 additions and 93 deletions) across 12 files** at the
measured checkpoint. Of those lines, 28 are tests, 7 are regression documents,
24 are generated localisations and the remaining 212 are production source,
most of it the chip code moving between files. Reproduce from the root:

```sh
git diff --numstat 5a324ccfe7cb47ac5114fd4f0166ce0e27f04acf 3ec37404f77d963e7d8315b1e03aae900a5d4954
```

The step target was 500; the repository soft cap is 1,500. This file, the
tracker row and the step 16 record correction come on top.

## Regression Documents

`projects-and-sessions.md` describes the chips on the phone and split-pane
lists. `desktop-cockpit-shell.md` says the phone shows the same shared chips.
