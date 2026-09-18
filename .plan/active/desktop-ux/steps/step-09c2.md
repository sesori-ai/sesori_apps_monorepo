# Step 9.c.2a — Sidebar activity projection

Delivery 16/21; branch `desktop-ux/sidebar-activity-foundation`.
Base: #1526 squash `a6b32359f028151649cc4553297bc60ace1c0383`, tree
`4d52ad1899e1de87690bc3fb4593f66a03eb82b0`.

## Scope

- Derive every running or live-unseen non-archived session across all loaded projects in a pure Layer-4 desktop
  projection, preserving project order and session order.
- Exclude projected activity IDs before choosing each project's ordinary three rows plus the selected active row.
- Require every recent-row caller to provide its exclusion set explicitly; the existing sidebar supplies `const {}`
  until the Flutter composition lands.
- Add no Flutter composition, explicit refresh operation, DI registration, request/cache owner, backend request,
  persistence, timer, project-view claim or analytics event.

## Review-driven split

The scoped plan review `7a64c300-5abd-46c6-8656-b75f8acb882d` rejected Layer-0 projection placement and widget-owned
refresh sequencing. Earlier implementation checkpoints then tried a Layer-4 orchestrator, Cubit-implemented operation
ports, and finally a Layer-3 request bus consumed by Cubits. PR review thread `PRRT_kwDORscidM6jyatt` correctly found
that the request bus still required mounted Layer-4 presentation owners to execute lower-layer operations. Thread
`PRRT_kwDORscidM6jyat1` also found that the added explicit session-refresh successor chain could lose a later winner
after a completed successor left the pending map.

Both invalid refresh additions are removed from this delivery rather than hidden behind another abstraction or grown
into a large correction inside an already reviewed PR. Project and recent-session Cubits, core and desktop DI, and the
desktop shell return to the merged #1526 behavior. The dedicated 9.c.2b delivery owns the substantive move of
authoritative fetch execution and state below presentation owners; prepared Flutter composition moves unchanged in
scope to 9.c.2c. This clean split follows the repository's review-convergence rule and adds no feature.

Final projection source checkpoint: `888e67c21e9387e54e9664d36d79442f0a0bb545`, tree
`b89d2d97877fb732b4387e2e9861521a1e171834`. Against the integrated base, client code measures 195 changed lines
(186 additions and 9 deletions) across six files, with zero generated churn:

```bash
git diff --numstat de6fdfe82ca84b05ce45cdeba6d0a1e48c2bb594..888e67c21e9387e54e9664d36d79442f0a0bb545 -- client
```

## Verification

Pinned Dart/Flutter 3.47.4 verification against exact source checkpoint `888e67c21e9`:

```bash
cd client/module_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/recent_sessions/recent_sessions_cubit_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../module_desktop_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../app
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/flutter test \
  test/core/widgets/session_split/session_split_shell_test.dart

cd ../desktop
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

git diff --check
```

Results: 18 recent-session cases, 2 projection cases, and all 11 previously failing app session-split cases pass;
module-core, module-desktop-core, and desktop analyzers are clean; diff check is clean. Evidence checkpoint
`787e9a6227410e6f6aac96956fdbb7e07c92be10`, tree `10fcca6b8d9f558482f7a7cf299e4034744b4b53`, measures 504
all-path changed lines (407 additions, 97 deletions) across 13 files: 85 production, 110 tests, 309 documentation,
and zero generated. This measurement includes the checkpoint version of this file; this evidence-only paragraph is
outside it. The app failures at published
head `43af1265c1` were `type 'Null' is not a subtype of type 'ProjectListCubit' in type cast` after the discarded DI
constructor change; removing that incomplete refresh wiring restores the established composition.

## Boundaries

Series-title metadata receipt: `/tmp/rose-elephant-series-21-title-receipts.json`. This prerequisite has no
user-visible, generated,
database, wire or bridge/plugin impact. 9.c.2b owns lower-layer refresh execution; 9.c.2c owns Flutter composition,
localization, regression docs and synthetic renders. No app smoke, GUI/helper/bridge, auth/preferences, registration,
secure storage or device operation ran. Native/live qualification remains required and unexecuted.
