# Step 37 — grouped rows and shell helpers

## Re-verification

- Found 39 planned `PregoGroupedRow.isLast` call sites still present. Group ownership remained valid; all app call sites and pass-through parameters were removable.
- Three background-task `PregoListTile.isLast` sites use a separate divider contract and were deliberately retained.
- Four settings pages still share top/content padding, but scaffold options, listeners, refresh behavior, navigation, and trailing slivers differ. A shared page shell would add parameter plumbing without reducing behavior ownership, so no shell was added.
- Three text clipboard paths remained duplicated. `syntax_highlight.dart` also still recovered silently.
- `_MeasureSize` and Prego `_HeightObserver` remained equivalent apart from reporting `Size` versus height.
- Pinned `flutter_keyboard_visibility` commit `a640afe883868faf2709c41daa391e2cd6f1fc7b` is `fix: restore Android API 24 support`; its diff only lowers plugin/example `minSdk` from 26 to 24. Replacement was tested with `MediaQuery.viewInsetsOf(context).bottom > 0`, but `system back dismisses the composer keyboard before popping the route` popped the route instead. Replacement was reverted; fork and keyboard implementation remain unchanged.

## Changes

- `PregoGroupedRows` now wraps children in private position scope; `PregoGroupedRow` suppresses divider from container-owned last position.
- Added `copyTextToClipboard`, returning success and logging recovered clipboard failures; all three text-copy paths use it. Syntax-highlight fallback now logs original error and stack trace.
- Added exported `PregoSizeObserver`; Prego scaffold measurements and session-detail composer measurement use it.
- Consolidated three identical Firebase platform-support getters into `_supportsFirebase`.
- Settings shell consolidation skipped after re-verification.

## Behavior impact

Refactor-only. Group dividers, copy success UI/analytics, syntax fallback, measured layout, startup gating, and keyboard behavior remain unchanged. Clipboard and syntax recovered failures gain diagnostics. No wire, persistence, database, localization, or generated-model impact.

## Change budget

Totals exclude this evidence file and use the merge base with `origin/main`:

```bash
BASE=$(git merge-base HEAD origin/main)
git diff --numstat "$BASE"...HEAD -- client/app/lib client/module_prego/lib
git diff --numstat "$BASE"...HEAD -- client/app/test client/module_prego/test
```

| Scope | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| Production/lib | 18 | 82 | 215 |
| Tests | 1 | 3 | 4 |

Twenty paths change including this evidence file. There is no new dependency,
DI registration, state, compatibility path, or generated source.

## Formatter caveat

`dart format lib test` hit known `dart_style` null-check crashes on existing primary/enhanced syntax after formatting some files. Unintended and generated formatter edits were restored. Touched format-compatible files were formatted explicitly; `prego_glass_scaffold.dart`, `prompt_input.dart`, and `harnesses_settings_screen.dart` remain formatter-blocked by that crash. `git diff --check` passes.

## Verification

- `flutter pub get` (`client/app`) — pass; lockfile unchanged after keyboard rollback.
- `flutter analyze --fatal-infos` (`client/module_prego`) — pass.
- `flutter test` (`client/module_prego`) — pass, 214 tests.
- `flutter analyze --fatal-infos` (`client/app`) — pass.
- `flutter test test/features/settings test/features/session_detail test/main_startup_notification_wiring_test.dart test/features/new_session/new_session_screen_test.dart` (`client/app`) — pass, 347 tests.
- Experimental MediaQuery keyboard run — failed direct system-back test and was fully reverted; final required matrix passes with fork.
- `git diff --check` — pass.

Architecture implementation review approved the grouped-row ownership,
exported size observer, clipboard utility boundary, and cross-package
integration with no findings. A separate correctness review found no plausible
regressions; the final manual audit additionally retained the unrelated
`PregoListTile` divider handling.
