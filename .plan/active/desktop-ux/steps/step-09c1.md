# Step 9.c.1 — sidebar refresh continuity

Delivery 15/19; branch `desktop-ux/sidebar-refresh-continuity`.
Implementation and focused verification complete; publication/merge recorded separately in the tracker/PR.
The original 9.c is split without added scope: this existing-owner lifecycle fix, then 9.c.2 UI composition.

## Immutable scope

- Base: `ed09171665995b98d1e010b9b5bd340c3c50a605` (#1524 squash).
- Base tree: `53e40902232a807cd91f83beaec669f95c084b9f`.
- Source/test checkpoint A: `f2d06b20b762aa96efb6396339b35d5414426fb3`.
- A tree: `8f1f26514df8631fd56a3b4be176178059414578`.
- Exactly two paths: `recent_sessions_cubit.dart` and `recent_sessions_cubit_test.dart`, in `client/module_core`.

```sh
git diff --numstat \
  ed09171665995b98d1e010b9b5bd340c3c50a605 \
  f2d06b20b762aa96efb6396339b35d5414426fb3
```

Production: 21 additions + 15 deletions = 36; tests: 117 additions = 117.
Total source review: **153 changed lines**, no generated output. Later evidence, regression docs,
series bookkeeping and #1524 merge receipt are excluded from A, not from the inclusive publication budget.
The PR body owns the final all-path size; this slice targets ≤650, including documentation.

## Behavior and ownership

Catalog/reconnect reads previously replaced usable loaded entries with loading placeholders.
`RecentSessionsCubit` now keeps current loaded/live-patched data through refresh and logged refresh failure.
One private pending-read identity map separates in-flight ownership from visible data; the existing changed-during-read
set still coalesces lifecycle mutations into one fresh snapshot before seeding shared unseen state.
Old completions cannot clear a newer request's identity, publish stale data or seed unseen state.
Initial loading/failure/retry and late-after-close guards remain intact.

All session fetch/filter/order/mutation behavior stays in `SessionListService`; live unread false keeps precedence.
Failures preserve the current live projection, not a captured older snapshot, and retain existing local diagnostics.
No new model, API, DI, subscription, timer, persistence, transport, backend rule or Flutter presentation change.
No new analytics action. No generation needed. Priority acquisition, manual refresh outcome UI, menu composition,
Prego reconciliation and control/tooltip changes remain 9.c.2, requiring their own concrete plan review.

## Verification

Pinned SDK: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin`.
At A, **46 non-hidden cases across two suites passed**, zero failures/skips; both analyzers were clean.

Cwd `client/module_core` — 13 cases and clean analysis:

```sh
dart test --reporter json test/cubits/recent_sessions/recent_sessions_cubit_test.dart
dart analyze --fatal-infos
```

Cwd `client/desktop` — 33 cases and clean analysis:

```sh
flutter test --no-pub --reporter json test/core/widgets/desktop_cockpit_shell_test.dart
dart analyze --fatal-infos
```

The six new cases cover pending catalog/reconnect refresh with live running/unseen updates, response/thrown failures,
immediate root create/update/archive/delete patches with one coalesced reread,
and older-completion/newer-read ownership. Existing initial deduplication, active ordering/pinning,
retry/invalidation, sibling isolation and disposal cases remain.
The desktop suite covers the existing consumer; it is not a real bridge/native lifecycle test.

Red measured index tree: `d44c215307aa4fb6140f28bfc1648dad6a0c9519` (a retained local tree, not a published commit).
Only the core test file differed from the frozen base; production code was still unchanged.
Cwd: `client/module_core`, relative to the repository root. Complete command with the pinned executable:

```sh
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test --reporter json \
  test/cubits/recent_sessions/recent_sessions_cubit_test.dart \
  --name 'pending .* refresh|refresh failure|lifecycle events during refresh|superseded refresh completion'
```

Exit **1**: **six non-hidden cases, all six failed, zero skipped**.
Four saw loading instead of useful loaded data; two failures replaced it with failed state.
The first post-fix run exposed two fixture assumptions about source ordering, not product defects: the service owns
ordering, so membership assertions became unordered while visible-order assertions stayed intact. The test enum also
needed its primary constructor. The final rerun replaces these intermediate results; none are added to the 46 total.
Reporter accounting excludes `testDone.hidden` events, not names containing “loading”.

Local manifests: `/tmp/rose-elephant-sidebar-refresh-red.json` and
`/tmp/rose-elephant-sidebar-refresh-final-verification.json`; the latter records exact commands, source tree and logs.

## Architecture evidence

Both complete reports are runtime-bound under the rose-elephant session's `subagent-artifacts/outputs/<run>/`.

- Plan workflow `f5dc2e69-aab5-4baa-b6c0-63cfe4e8c970`, child `cc4113d3-6ac0-464b-a228-98bd78619d4c`:
  `sidebar-refresh-plan-architecture.md`, 347 bytes, **APPROVED** only 9.c.1 against the frozen base.
  SHA-256 `058e2a8aa87c2883cad8b60887edec27bdc7de50b27014f397d7ca1aa5bf50a1`.
- Implementation run `bc01e5a9-c4ea-4ad4-a750-a925f8c21f92`:
  `sidebar-refresh-implementation-architecture.md`, 695 bytes, **APPROVED** exact base..A/two paths/153 lines.
  SHA-256 `8bd8592754af70e14dc66778db98923051afb22ecab5d4c78121adfaa487e76c`.

Fresh read-only medium-intelligence reviewers; B-Client applied, B-Bridge/B-Shared skipped.
The implementation report excludes later parent-written docs. Neither reviewer ran tests, generation or native tools.
Reports approve architecture, not runtime/native qualification or the later 9.c.2 composition.

## Delivery and qualification boundaries

Series titles now use 19 slots; the fourteen already-merged PR metadata titles were updated without rewriting Git
subjects or published history. Receipt: `/tmp/rose-elephant-series-19-title-receipts.json`.
No protected GUI, bridge/helper, production DI, app smoke, auth/preferences, registration, bundle or device operation.
No new visual fixtures were needed for this pure-Dart owner change. Native scrolling/indicator efficiency, relaunch
persistence and broader live/packaged/backup qualification remain required but unexecuted.
The known 250% shared-header overflow is unchanged; lower-scale success does not resolve it.
