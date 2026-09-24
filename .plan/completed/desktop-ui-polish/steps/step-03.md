# Step 3 — Activity shows only sessions in motion

## Scope

- Activity lists a session while it is **in motion**: running, or unseen and
  not set aside. `DesktopSidebarSessionProjection.from` stays a pure function;
  its rule is `isRunning || (isUnseen && !isDeferred)`.
- **Set aside.** Marking a session unread on the desktop records
  `session id → time.updated` in `DesktopSidebarLayout.deferredSessions`,
  through the new `onSessionMarkedUnread` hook on the desktop's
  `SessionListActionDispatcher` (the phone passes `null`). The session is
  deferred while its stamp still equals the recorded one. The map lives in the
  existing desktop-local layout file, keeps the newest 200 entries and is per
  desktop.
- **Sticky selection.** An Activity session the user opens stays listed until
  the selection changes; the id is widget state in the sidebar, taken from the
  previous build's Activity ids so the mark-seen that follows opening a session
  cannot race it. Setting the open session aside is explicit, so it beats the
  sticky selection and the session leaves Activity at once.
- **No relocation.** Sessions never leave their project's rows:
  `RecentSessionsResolvers.rows` lost `excludingSessionIds` and the projection
  no longer tracks activity ids per project. The collapsed rail's sparkle badge
  shows only on a running or unseen session.
- No wire, database or analytics change. The layout file gains one defaulted
  field; a file written before this step reads as "nothing set aside".

## The `time.updated` Finding

Audited before any code, as the plan requires. Stamp equality works for every
registered plugin, so the plan's running-session fallback was not built.

- The wire `Session.time.updated` is computed by the bridge, not by a plugin:
  `SessionCatalogMapper.map` returns
  `max(sessions.updated_at, sessions.last_user_message_at)`.
- `updated_at` moves on session creation, on turn or idle completion using the
  bridge's clock (`recordSessionCompletion` → `advanceUpdatedAt`, never
  backwards), on live projection updates during a turn, on rename, on archive
  and on catalog import. Every merge takes the maximum. No periodic job
  rewrites it.
- Mark read and mark unread (`POST /session/seen` → `SessionUnseenService`)
  write only the unseen columns and never either input of the stamp; their
  `session.unseen_changed` echo carries no time field. Marking unread therefore
  cannot undo its own deferral.
- A moved stamp reaches the desktop as a `session.updated` event. The client
  decodes it as `SesoriSessionUpdated`; `RecentSessionInventoryService` hands
  it to `SessionListService.applySessionUpdatedEvent`, which replaces the
  session, stamp included, in the list the sidebar projects.
- All eleven plugins (OpenCode, Antigravity, Codex, Copilot, Cursor, Claude
  Code, Hermes, Pi, OMP, DeepSeek, Grok) share this one bridge path, so the
  rule stays backend-neutral.
- Accepted limits, recorded in `PLAN.md` under Risks: renaming a session stamps
  it, and a cold Claude Code or Pi catalog import reads the transcript file's
  modification time. Either can return a deferred session to Activity once; the
  user sets it aside again.

**Deviation from the plan as first merged.** The plan pruned entries that were
no longer unseen on every write. The cubit sees only the projects loaded so
far, so that pruning could drop a set-aside session of a project that had not
loaded yet. An entry is inert once the agent moves the session's stamp, and the
200-entry cap bounds the file, so nothing else prunes. `PLAN.md` is amended in
this PR.

## Automated Evidence

Measured checkpoint: commit `278914c9cd77d814c2909e601cf2ba41c5fcc926` with a
clean working tree, Flutter 3.47.4 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

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
flutter test --no-pub test/features/session_list
flutter analyze --no-pub
cd ../app
flutter test --no-pub test/features/session_list test/core/widgets/connection_banner_test.dart
flutter analyze --no-pub
```

- `module_desktop_core`: 23 cases pass. The projection cases prove running and
  unseen sessions in owner order; a set-aside session stays out while a second
  one whose stamp moved (5 → 9) is back; running beats a deferral; the opened
  session stays listed only while it is the sticky one; an Activity session is
  still in its project's rows. The cubit case proves the persisted stamp,
  re-deferring counted as newest and the cap dropping the oldest. The storage
  case round-trips the map in insertion order and reads a file without the
  field as empty.
- `module_core`: 27 cases pass with `rows(selectedSessionId:)`.
- `desktop`: the full suite, 247 cases, passes. The new shell case drives the
  whole flow: an unseen session shows in Activity and under its project, stays
  while selected, leaves after `deferMarkedUnreadSession`, and returns when its
  stamp moves from 5 to 6.
- `module_app_ui`: 42 cases pass. `app`: 68 cases pass; the swipe suite proves
  the hook fires on mark unread and never on mark read.
- All five analyzer runs report no issues. `desktop_sidebar_layout.freezed.dart`
  and `.g.dart` were regenerated with
  `dart run build_runner build --delete-conflicting-outputs` in
  `client/module_desktop_core`.
- Architecture review: `architecture-implementation-review` ran once through a
  sub-agent on this branch against `main` and approved it with no violations
  and no required changes. Its one optional note, a comment saying why
  `_activitySessionIds` is assigned during build, was added before the measured
  checkpoint.

### Review follow-up

Commit `6464e2b0dc1648cad5def9600a22351a53402d4e` lets an explicit set-aside
beat the sticky selection (Codex) and corrects the plan's marker wording
(cubic). Its only code change is in `module_desktop_core`, so that package and
its consumer were re-run on that commit with a clean tree; every command
exited 0. The other packages' results above stand.

```sh
cd client/module_desktop_core
dart test test/cubits/desktop_sidebar_cubit_test.dart \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart \
  test/api/desktop_instance_storage_test.dart
dart analyze
cd ../desktop
flutter test --no-pub
flutter analyze --no-pub
```

23 and 247 cases pass; the projection case now also proves that a set-aside
session is not listed even while it is the sticky one.

## Size

**522 changed lines = 353 additions + 169 deletions** at the measured
checkpoint, including 52 generated lines (the two layout files) and 23 lines of
`PLAN.md`. Reproduce from the root:

```sh
git diff --numstat 9e771cabc2f38caa9f61d460ac8bbac20d716106 278914c9cd77d814c2909e601cf2ba41c5fcc926
```

The base is `git merge-base origin/main 278914c9cd77d814c2909e601cf2ba41c5fcc926`.
The step target was 600; the repository soft cap is 1,500. This file, the
tracker row and the review follow-up come on top
(`git diff --numstat 9e771cabc2f38caa9f61d460ac8bbac20d716106 6464e2b0dc1648cad5def9600a22351a53402d4e`
gives 671 = 499 + 172); final self-inclusive accounting belongs in the PR body.

## Regression Documents

`desktop-cockpit-shell.md` now describes Activity as the sessions in motion,
sessions that never leave their project, setting a session aside by marking it
unread (per desktop, newest 200) and the opened Activity session that stays
until the selection changes, with the matching coverage and failure signals.
