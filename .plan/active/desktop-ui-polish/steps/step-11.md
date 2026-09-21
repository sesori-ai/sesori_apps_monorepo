# Step 11 — Session page toolbar and centred column

## Scope

- **Page frame (D11).** `SessionDetailBody` takes one required nullable
  `SessionDetailPageChrome`: a `headerBuilder` and a `maxContentWidth`, both
  non-null, so a toolbar without a width cap cannot be expressed. With it the
  body lays the header above the transcript instead of floating a glass bar
  over it, zeroes the top-bar inset, and passes the width to the loaded view,
  which applies it as scroll padding on the transcript and as side insets on
  the bottom controls. The wheel and scrollbar keep the whole pane. The phone
  passes null and is unchanged.
- **Desktop toolbar.** The desktop passes 760 and a builder returning
  `DesktopPageToolbar`, which gains a required nullable `leading` slot: Back
  only on a pushed page, title with agent and model, busy indicator,
  **Mark unread**, **Changes** while the session has a diff, and a `…` menu.
- **Session actions.** `SessionDetailLoaded` gains the hydrated `Session` the
  cubit already held privately, as a required nullable field kept current by
  `session.updated`. The menu reuses the sidebar's precedent: a throwaway
  `SessionListCubit` in actions mode driven by the one desktop dispatcher.
  Actions stay disabled until the session is non-null, and work for child
  sessions and sessions opened directly.
- **Mark unread.** The dispatcher gains `handleSessionMarkUnread`, which always
  sends `read: false` and fires the existing mark-unread hook, because local
  state can still say unseen just after opening. The page then goes to the
  project page. `sessionMenuEntries` takes a required `includeReadToggle` so
  the toolbar's menu does not repeat the action.
- One new string ("Changes"). No wire, database or analytics change.

## Deviations From The Plan

- `Shift+Cmd/Ctrl+U` is bound by the desktop session page, not beside the
  shell bindings in `desktop_router.dart`. Only the page's cubit holds the
  hydrated session, and the shell sits above it. The shortcut is therefore
  inert off a session route by construction, and also while focus is outside
  the session page, such as in the sidebar.
- The menu offers Rename, Archive and Delete. The separate **Archive, keep
  worktree** entry arrives with step 12's immediate cleanup flow, which is what
  splits it from the archive sheet.
- The regression document also records that the project page's chips hide
  while a project has no sessions, the wording gap cubic raised on #1576.

## Automated Evidence

Measured checkpoint: commit `fe180520a448cf3083f352de9364f3ae84f7174b` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/module_core
flutter test --no-pub
flutter analyze --no-pub
cd ../module_app_ui
flutter test --no-pub
flutter analyze --no-pub
cd ../app
flutter test --no-pub
flutter analyze --no-pub
cd ../desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `module_core`: 1830 cases pass. The `session.updated` case now also proves
  the loaded state carries the hydrated session and keeps it current.
- `desktop`: 272 cases pass. Five new cases prove the toolbar sits above a
  transcript with no top inset and the computed side inset, that session
  actions and the shortcut are inert until the session is hydrated, that Mark
  unread sends `read: false` for a session local state still calls unseen,
  fires the deferral hook and leaves the page, that the shortcut does the
  same, and that a child session's menu offers Rename, Archive and Delete
  without a read toggle.
- `module_app_ui`: 391 cases pass. `app`: 774 cases pass, which covers the body
  without page chrome. All four analyzers report no issues.
- From `client/module_core`, `dart run build_runner build
  --delete-conflicting-outputs` exited 0. From `client/module_app_ui`,
  `flutter gen-l10n` exited 0. Nothing generated was edited by hand.
- Layout was checked once in rendered output at 1400 pt wide.
- `architecture-implementation-review` ran once through a sub-agent over this
  commit against `origin/main` and approved it with no findings, including the
  shortcut's placement.

## Size

**746 changed lines (608 additions and 138 deletions) across 25 files** at the
measured checkpoint; 39 are generated, 226 are tests and 18 the regression
document. About 140 of the rest is re-indentation in `SessionDetailBody`,
whose state switch moved into a method both frames share. Reproduce from the
root:

```sh
git diff --numstat 5ae932dd0469207df0f45386dd504d30aee037e6 fe180520a448cf3083f352de9364f3ae84f7174b
```

The step target was 700; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` gains the session page's required behaviour and its
automated coverage, and the chips' empty-project condition.
