# Step 6 — Fold And Unfold Every Turn From The Bar And The Keyboard

Branch `turn-navigation/fold-controls`. Architecture 6.

## Plan Claims Checked

- Step 5 captures the top-edge turn in the list's `didUpdateWidget` whenever
  `transcriptFolded` changes, so the buttons and shortcuts need no anchor code
  of their own. The iOS check below confirms it.
- `setTranscriptFolded` already ignores a repeated value, so reporting inside
  its folded branch sends `transcript_turns_folded` once per actual fold.
- The desktop already builds platform shortcuts through `desktopShortcut` and
  labels them through `desktopShortcutLabel`, the same meta/control check as
  `_MarkUnreadShortcut`. `module_app_ui` receives the activators and has no
  platform branch.

## Scope Delivered

- `ProductAnalyticsEvent.transcriptTurnsFolded()` with no parameters, retained
  like the other deferred candidates; the cubit reports it on a fold only.
- The phone bar's `PregoButtonsIconGlass` on a loaded session: "Fold all turns"
  while unfolded, "Unfold all turns" while folded.
- `SessionDetailPageChrome` requires `foldActivator` and `unfoldActivator`; the
  body binds them with `CallbackShortcuts` around the page.
- The desktop toolbar button `desktop-session-page-fold` between Changes and
  More, with the shortcut in its tooltip: ⌘−/⌘= on macOS, Ctrl elsewhere.
- `docs/regression/transcript-turn-navigation.md`, its index entry, cross
  references from the turns, history and tools documents, and "Transcript turn
  boundaries" in `docs/HARNESS_CAPABILITIES.md`.
- `TranscriptTurnStub` copy and the "Working…" row are unchanged.

## Deviation

- The desktop test's `pumpPage` gained an optional `transcriptFolded` flag,
  test-only.
- **User decision: every fold and unfold holds the top-edge turn, even while
  following.** The iOS check found that a fold from one of the last few turns
  clamps at the latest edge, where the list followed again, so step 5's "while
  following, a switch keeps following" sent the next unfold to the end of the
  latest turn. The user accepted that an unfold at the bottom of a running
  turn now stops following until the reader scrolls down. The list drops its
  `!_follow.following` condition; the hold's first jump detaches the list, as
  a stub tap's already did, so nothing re-snaps to the edge. PLAN.md's anchor
  rules say so. The step 9 pinch rows ("while following it stays following")
  are left for step 9 to reconcile.

Size: 549 changed lines before this correction, against the 650-line target. The first push was
439; the Codex focus fix and this decision added the rest.

## Automated Evidence

Toolchain: Dart 3.13.4 from Flutter 3.47.5. `dart analyze --fatal-infos` is
clean in `module_core`, `module_app_ui`, `client/app` and `client/desktop`.
`dart format -l 120` changes no touched hunk.

| Command | Result |
|---|---|
| `flutter test` in `client/module_core` | 924 passed (analytics event, cubit fold reporting) |
| `flutter test test/features/session_detail/` in `client/module_app_ui` | 314 passed (2 new: the clamp round trip and a switch while following; both fail with the old condition) |
| `flutter test test/features/session_detail/` in `client/app` | 168 passed (phone button) |
| `flutter test test/features/sessions/desktop_session_detail_screen_test.dart` in `client/desktop` | 13 passed (button, tooltips, shortcuts on macOS and Linux) |

## Review

`architecture-implementation-review` over `origin/main...HEAD` approved with no
findings.

Codex found that the page shortcuts fired only once the composer had focus.
The desktop page now takes focus when it opens and when a click lands in it,
leaving focus already inside it alone. The shortcut test no longer focuses
the composer and covers a click returning focus.

## Manual

- iOS: run on simulator `sesori-dev-2` with slot 2's own bridge and a synthetic
  OpenCode session of five numbered-list turns. From mid-turn two, the button
  folds with turn two's prompt at the top edge and unfolds with it still there;
  from a prompt near the top the same holds. Before the user decision, from
  mid-turn three the fold clamped at the latest edge and the unfold followed to
  the end of turn five (see Deviation); the fix is covered by widget tests and
  was not re-run on the simulator. Recordings are on `pr-media` under
  `turn-navigation/fold-controls/`.
- macOS toolbar and shortcuts: not run. The user's debug Sesori desktop app was
  running, and a second desktop instance manages its own bridge helper with
  single-bridge ownership and instance takeover, so it could fight the user's
  app. Widget tests cover the button, tooltips and both platform activators.
