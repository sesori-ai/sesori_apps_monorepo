# Step 3 — Recent sessions per project

## Scope

- One surface-neutral `RecentSessionsCubit` per signed-in cockpit, with five
  shared-stream subscriptions and immutable per-project entries. Existing
  `SessionListService` owns inventory, ordering, filtering and mutation helpers;
  `RecentSessionsResolvers` derives three recent rows plus the open session.
- Live create/update/delete, activity and unread projection; retry, reconnect
  and catalog invalidation. Mutations during a read coalesce into a fresh
  snapshot. Superseded/closed reads cannot seed unseen state.
  Retry requests data through the service, not transport reconnection.
- Project collapse persists with the existing sidebar layout. Header hover or
  keyboard focus reveals New session. Existing project/session menu builders
  and main-pane routes are reused; “All sessions · N” counts visible active rows.
- Lazy `SessionListMode.actions` scopes reuse existing mutations without an
  initial fetch, project-view claim or route-navigation refresh. Each menu
  synchronizes its named target from the recent inventory without replacing
  other rows or their pending mutations. Normal desktop
  and mobile lists use `SessionListMode.view`; their behavior remains unchanged.
- No new analytics event: existing creation/action outcomes remain authoritative.
  No wire contract or database change; only desktop layout JSON gains a field.
- Approximately 1,400 changed lines, including 87 generated lines: above the
  1,200-line step estimate, below the repository soft cap. Review fixes and
  reproducible evidence account for the follow-up growth.
  The shared action/viewing seam and its focused coverage stay with their real
  sidebar consumer rather than landing an unused intermediate API.

## Automated Evidence

- Recent cache: seven cases cover lazy/deduplicated reads, active ordering and
  pinning, live state/mutations, invalidation, retry, stale reads and disposal.
- Existing session-list cubit/service cases pass, including a new seeded-action
  case proving no initial fetch/view claim and preserving normal rename refresh.
- Nineteen cockpit cases pass, including native-macOS versus Flutter renderer
  selection, tree selection/navigation, project collapse persistence, hover New
  session, shared project menus and package-font/single-line count labels.
- Five router and nineteen sidebar/storage cases pass. Localization and sidebar
  model generation pass. All five touched client package analyzers pass.
- Architecture pass 1 identified direct transport retry and logic inside the
  state model. Both were fixed locally; fresh-context pass 2 approved the
  resulting boundaries with no remaining architectural findings.

## Reproducible Verification And Size

Follow-up commands ran on clean committed code `7f0c7d95c7f6686ad32b977c0f35deb46c569126`,
tree `01550ede079972f5e92debfdb8c87c3c6bfa53c5`, before this documentation-only
update. Root cwd: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.

| Cwd below root | Exact command | Result |
|---|---|---|
| `client/module_core` | `dart test test/cubits/recent_sessions/recent_sessions_cubit_test.dart test/cubits/session_list/session_list_cubit_test.dart test/services/session_list_service_test.dart --reporter expanded` | 80 pass |
| `client/desktop` | `flutter test test/core/widgets/desktop_cockpit_shell_test.dart test/core/routing/desktop_router_test.dart --reporter expanded` | 24 pass (19 cockpit + 5 router) |
| Each of `client/module_core`, `client/desktop` | `dart analyze --fatal-infos` | clean |

Unchanged-area baseline checks ran locally in the pre-commit working tree that
became `b7d90847f031a286713a67996afb8b06ecfae2fe`; they are not post-commit runs:
`client/module_desktop_core`: `dart test test/cubits/desktop_sidebar_cubit_test.dart test/api/desktop_instance_storage_test.dart --reporter expanded` (19 pass).
`dart analyze --fatal-infos` also passed in each of `client/module_desktop_core`,
`client/module_app_ui`, and `client/app`. Generation used
`dart run build_runner build --build-filter=lib/src/foundation/desktop_sidebar_layout.*.dart`
in desktop core and `flutter gen-l10n` in app UI. The four fixture cases used
`flutter test .dart_tool/recent_sessions_preview_test.dart --reporter expanded`
in desktop. Current follow-up logs retain head/tree/cwd/command headers at
`/tmp/rose-elephant-1494-*-followup.log`. Baseline CI also passed 12/12 on #1494.

Size uses `git diff --numstat 2173b7975814ac346fd6c6ee6c9a16f811961732 <head>`
from the root; that base is `git merge-base origin/main 7f0c7d95c7f6686ad32b977c0f35deb46c569126`.
Sum additions plus deletions across **all** rows, including generated output
and this evidence document. `b7d9084`: 1,228 + 74 = 1,302; `7f0c7d9`:
1,306 + 75 = 1,381. Both include 87 generated lines. The final documentation
head and self-inclusive total are recorded in the PR body rather than embedding
a recursively changing commit hash here.

## Visual Evidence And Limits

Four font-loaded production-widget fixtures cover light/dark 260-pixel layouts,
200-pixel minimum width and the compact rail. Initial previews exposed missing
package-font styles/wrapping in count/retry controls; those were corrected.
Synthetic data includes running/unread/awaiting sessions, an open fourth row,
a failed project, and a collapsed project. Artifacts are private/local under
`/tmp/rose-elephant-qa.mri9JX/recent-*`; the probe source is ignored.

The inspected comparison was shown to the user. These are Flutter/Linux-renderer
fixtures, not native macOS compositing,
energy-efficiency or live-bridge verification. Production Apple indicators
remain native. The current GUI and standalone bridge were not relaunched,
taken over or stopped; no auth/storage prompts were triggered. Prior locked-GUI
and pinned-SDK profile blockers remain recorded in `step-02b.md`.

Native tree scrolling/clipping, menu/lifecycle behavior, steady Flutter frames,
live session actions, persisted-layout relaunch and the final platform matrix
remain required before shipping/plan retirement. Per the user's direction,
these outstanding checks do not draft or block this implementation PR or its
successor. Main-pane redesign, Bridge popover and modal Settings remain later
steps.
