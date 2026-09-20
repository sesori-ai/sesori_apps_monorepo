# Step 4 — Labelled sidebar sections and Show more in place

## Scope

- **Sections.** "Activity · N" and "Projects" are labelled section headers
  (`DesktopSidebarSectionHeader`, its own file). Clicking a header folds its
  rows. The two flags, `activitySectionCollapsed` and
  `projectsSectionCollapsed`, are defaulted fields of the existing
  `DesktopSidebarLayout`, written through `DesktopSidebarCubit`'s queue by
  `toggleActivitySection` and `toggleProjectsSection`. A layout file written
  before this step reads as unfolded. The collapsed rail has no headers, so it
  ignores folding and keeps showing both lists. N counts the Activity
  sessions; the header has zero height and leaves the focus order while
  Activity is empty.
- **New project** moved from beside the New session button onto the Projects
  header, as step 2 announced.
- **Show more (D3).** `RecentSessionsResolvers.rows` takes a required `limit`.
  `_SidebarProjectGroupState` owns it: three rows, ten more per click, back to
  three when the project folds. The selected session stays pinned below the
  head. The "All sessions · N" button and its `desktopSidebarAllSessions`
  string are deleted; the project name is the one door to the sessions page.
- **Row anatomy (D6).** Every session row leads with a fixed 28-point status
  column under the project avatar (awaiting-input icon and the unchanged
  sparkle) and ends with a compact last-activity time from the existing
  `formatTimestampCompact`. A running session shows no time. A narrowing row
  drops the time before its title. Activity rows keep the project name under
  the title; in the rail they keep the project avatar with its sparkle badge
  until step 5 replaces the per-session rail chips.
- No wire, database or analytics change. The phone is unchanged.

**Deviation from the agreed mockup.** The mockup names an Activity row's
project with a 16-point avatar at the trailing edge. `PregoAvatarInitials`
draws its initials at a fixed size that does not fit 16 points, and the design
system is out of this step's scope, so the row keeps the project name as its
second line and the trailing edge carries the time, like every other row.

## Automated Evidence

Measured checkpoint: commit `a5c3f21f3eea457d4224e8367cd3eecfe750790f` with a
clean working tree, Flutter 3.47.4 (Dart 3.13) from `.tool-versions`. Every
command below exited 0.
No log files were kept; CI on the PR is the durable record. This file and the
tracker row were added afterwards as documentation only and were not
re-measured.

```sh
cd client/module_desktop_core
dart test test/cubits/desktop_sidebar_cubit_test.dart \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart \
  test/api/desktop_instance_storage_test.dart
dart analyze
cd ../module_core
dart test test/services/recent_session_inventory_service_test.dart
dart analyze
cd ../desktop
flutter test --no-pub
flutter analyze --no-pub
cd ../module_app_ui
flutter analyze --no-pub
cd ../app
flutter analyze --no-pub
```

- `module_desktop_core`: 24 cases pass. The new cubit case folds Activity, then
  Projects, then unfolds Activity, and proves each write and that one section
  never moves the other. The storage case round-trips both flags and reads a
  file without them as the default layout.
- `module_core`: 27 cases pass. The resolver case proves `limit: 1` returns
  the head plus the pinned selection and that a limit past the end returns
  every row.
- `desktop`: the full suite, 249 cases, passes. New shell cases: Show more
  grows 3 → 13 → 15 rows, disappears when nothing is left and starts over at
  three after the project folds; folding each header hides its rows and
  persists both flags in one layout, and collapsing to the rail shows both
  lists again. Updated cases: the header reads "Activity · 2"; New project is
  found inside the Projects header; a fully shown tree offers no Show more.
  The three sidebar-shortcut variants and the two rail-collapse cases pump the
  collapse animation frame by frame, which is what caught the header
  overflowing at near-zero width before its width guard.
- `module_app_ui` and `app`: analyzers clean after the string changes
  (`desktopSidebarAllSessions` deleted, `desktopSidebarShowMore` added,
  `desktopSidebarActivity` takes a count). Localizations were regenerated with
  `flutter gen-l10n` in `client/module_app_ui`; `desktop_sidebar_layout`'s
  freezed and json output with
  `dart run build_runner build --delete-conflicting-outputs` in
  `client/module_desktop_core`.
- Architecture review: `architecture-implementation-review` ran once through a
  sub-agent on this change's diff, before it was rebased unchanged onto the
  merged step 3, and approved it with no violations and no notes.

### Review follow-up

Measured at commit `aa6f4bb608d648f85b7e38d9ac6ff62b7e05e65d` with a clean
working tree and the same toolchain. Both commands exited 0; no log files were
kept. This section was added afterwards as documentation only.

```sh
cd client/desktop
flutter test --no-pub
flutter analyze --no-pub
```

- The first review wave found that a row's new time never reached a screen
  reader, because the row's label replaces its children's semantics. The label
  and tooltip of both row kinds now end with the time in full ("3h ago"),
  while the row keeps the compact "3h".
- The time's reveal width was a fixed 104 points. It now grows with the system
  text scale, so larger text drops the time instead of squeezing the title. At
  the default scale nothing changes: measured against the bundled font, the
  longest stamp (a full numeric date, 59 points at 12-point text) and the
  row's fixed parts (40 points) fit in 104.
- `desktop`: the full suite, 250 cases, passes. The new shell case proves the
  compact time, the full phrase in the tooltip and the semantics label, and
  that a 2.5× text scale drops the time while the title and the spoken phrase
  stay. With the text-scale term removed the case fails (checked once by
  hand, then restored). `flutter analyze` reports no issues.
- One regression-document bullet held multi-byte punctuation and measured 114
  characters but 123 bytes; it now wraps under 120 by either count.
- The fix adds 82 changed lines (60 additions + 22 deletions) in three files:
  `git diff --numstat 21e01cdb71 aa6f4bb608d648f85b7e38d9ac6ff62b7e05e65d`.

## Size

**631 changed lines = 420 additions + 211 deletions** at the measured
checkpoint, including 60 generated lines (freezed, json and localization
output). Reproduce from the root:

```sh
git diff --numstat d9d885ab25b80e4ef008aa71fbf7cb5c088fd177 a5c3f21f3eea457d4224e8367cd3eecfe750790f
```

The base is `git merge-base origin/main a5c3f21f3eea457d4224e8367cd3eecfe750790f`.
The step target was 700; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` now describes the two labelled, foldable section
headers and their persistence, the rail ignoring folding, New project on the
Projects header, Show more in place of the "All sessions" link, and the row
anatomy (leading status column, trailing compact time), with the matching
coverage and one new failure signal.
