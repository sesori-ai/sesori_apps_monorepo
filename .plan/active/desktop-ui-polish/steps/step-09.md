# Step 9 — Desktop project page as one timeline

## Scope

- **Page toolbar.** `client/desktop` gains `DesktopPageToolbar`: a title with
  an optional subtitle on the left and the page's actions on the right, on the
  surface colour over a bottom hairline. Step 11 reuses it for the session page.
- **Project page (D10).** `DesktopSessionListScreen` no longer wraps the phone's
  `SessionListScaffold`. It is the toolbar over the shared `SessionListContent`
  in a column capped at 760 points, centred by sliver padding so the wheel and
  the scrollbar belong to the whole pane. The toolbar names the project and its
  repository, toggles **Archived** (the cubit's `toggleArchived`), owns **New
  session** as the primary button, and keeps **Refresh sessions** and **Scan
  for sessions** in an overflow menu, because a mouse has no pull gesture.
  Nothing floats over the list.
- **One timeline.** `SessionListContent` takes the required closed
  `SessionListGrouping` (`runningSection`, `timeline`). The phone's three call
  sites pass `runningSection` and are unchanged. With `timeline` a running
  session is headed **Today** whatever its stored time. The service-owned
  order, running first, does not change.
- **Pointer rows.** Under the pointer scope from step 8, `SessionTile` has a
  44-point floor, a 14-point title, a fixed leading column for the unchanged
  `PregoAiLoader` sparkle, the time always in the trailing slot ("Running"
  while an agent works, spoken once through the sparkle), and the sidebar's
  hover colour. The touch row is unchanged.
- Three new strings (Archived, Refresh sessions, Scan for sessions). No wire,
  database or analytics change. Filter chips and hover actions are step 10.

## Automated Evidence

Measured checkpoint: commit `cb41d6a9630a42e68da215d1765ac0bb76cdcf94`,
Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. The suites ran on this
content before it was restaged onto the merged step 8, whose one later
one-token fix in `module_prego` was measured in its own PR. Every command
below exited 0. No log files were kept; CI on the PR is the durable record.
This file and the tracker row were added afterwards as documentation only and
were not re-measured.

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

- `module_app_ui`: 388 cases pass. New cases prove the timeline grouping puts
  a session running since yesterday first under Today with no Running or
  Yesterday heading, a pointer row's height, and a running pointer row leading
  with the sparkle and ending with "Running".
- `app`: 774 cases pass. `desktop`: 265 cases pass, including the first
  project page tests: the toolbar's title and New session button, no floating
  button, and the Archived toggle calling the cubit and reading as on. The
  router test now asserts the page's project name rather than the removed
  scaffold. All three analyzers report no issues.
- `flutter gen-l10n` regenerated the two localisation files; nothing generated
  was edited by hand.
- Appearance, the 44-point rows and the hover highlight were checked once in
  rendered output with the packaged fonts, in light and dark; the images were
  not kept in the repository.
- Architecture review (`architecture-implementation-review`, one run):
  approved with no findings.

## Size

**516 changed lines (466 additions and 50 deletions) across 15 files** at the
measured checkpoint; 27 are generated localisation lines, 163 are tests and 15
the regression document. Reproduce from the root:

```sh
git diff --numstat 86a91ae34345826eb8c08d8c6f945251414f24bd cb41d6a9630a42e68da215d1765ac0bb76cdcf94
```

The base is `git merge-base origin/main cb41d6a9630a42e68da215d1765ac0bb76cdcf94`.
The step target was 800; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` replaces the all-sessions sentence with the page's
required behaviour (toolbar, timeline, pointer rows, unchanged phone) and lists
its automated coverage.
