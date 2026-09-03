# Step 20 slice 2/3 — Desktop cockpit composition

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Desktop users get a persistent cockpit shell with adaptive project/session navigation, truthful supervision recovery, desktop keyboard behavior, and usable source selection.
- **Dependencies:** Step 20 slice 1/3 (window bounds), Steps 14–19
- **Pinned implementation head:** `987628af04383831d8d53c1846b7a8cfc3197452`

## Scope

- Compose the desktop Bridge, Projects, and Settings cockpit around the existing typed routes.
- Keep project/session inventory mounted across wide-window child navigation while retaining narrow-window routing.
- Centralize desktop helper-plus-relay recovery behind the desktop-core cubit and relay service.
- Add desktop Enter/Shift+Enter, IME-safe submission, and Escape policies.
- Make transcript/diff source selectable without navigation, file-header, line-number, or `+/-` presentation metadata.
- Keep notification-open routing and its router-readiness adapter out of this slice; their first production consumer lands with slice 3.

## Implementation Summary

- Added `DesktopCockpitShell` with persistent sidebar navigation, app-wide supervision surfaces, and shell-owned exceptional recovery presentation.
- Added adaptive typed desktop routes and project-scoped nested session-list ownership so wide layouts preserve the inventory beside detail, new-session, and diff destinations.
- Moved relay-status branching into `DesktopRelayConnectionService` and exposed `BridgeControlCubit.recoverConnection()` as the single Layer-4 intent used by cockpit and project recovery UI. Mobile recovery behavior remains unchanged.
- Kept `module_app_ui` presentation shell-neutral through explicit composer capabilities and a desktop send-key policy; mobile composes its modifier-send policy explicitly.
- Added IME candidate-confirmation protection, generic typed Escape popup dismissal, and source-only selection boundaries across shared diff rows and desktop navigation/file headers.
- Deferred the future-only `DesktopRouteDispatcher` and router-readiness fence after review identified that slice 3's attention open flow is their first production consumer.
- Updated the affected supervision, projects/sessions, diffs/source-control, and session-turn regression contracts.

## Architecture Review

- The first bounded review rejected two issues: transport branching leaked into desktop router composition, and desktop session detail required the later slice's unregistered notification canceller.
- Moved recovery policy into `DesktopRelayConnectionService` plus the single `BridgeControlCubit.recoverConnection()` orchestration intent, restored `notificationCanceller: null`, and removed the future-only route adapter/readiness machinery from this slice.
- The second bounded review over the authoritative v3 artifact was **APPROVED** with no findings. It confirmed shared/shell ownership, nested inventory lifecycle, recovery boundaries, keyboard/IME policy, and selection boundaries.
- The post-rebase patch ID is unchanged (`691e7ffec3406091fd02e230cc47e3cc415439b6`), so the reviewed implementation content is identical on top of merged PR #1267.

## Verification

- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 219 tests.
- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 281 tests.
- `client/module_prego`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 267 tests.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 104 tests.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 660 tests.
- Dart LSP reports zero diagnostics across all 17 changed production Dart files.
- A clean `asdf exec flutter build macos` succeeds (65.8 MB reported by Flutter), and `codesign --verify --deep --strict` accepts the resulting app bundle.
- `git diff --check` passes.
- The pinned implementation range is `3686d12d4f2456b0d6484a6f9f48d1661dc410f7..987628af04383831d8d53c1846b7a8cfc3197452` (the base is the merge commit for PR #1267). The exact non-self-inclusive reproduction is:

```bash
base=$(git merge-base 3686d12d4f2456b0d6484a6f9f48d1661dc410f7 987628af04383831d8d53c1846b7a8cfc3197452)
git diff --numstat "$base" 987628af04383831d8d53c1846b7a8cfc3197452 \
  | awk '{ additions += $1; deletions += $2 } END { print additions, deletions, additions + deletions }'
# 1414 281 1695
```

The 1,414 additions plus 281 deletions reconcile to 1,695 total changed lines across 37 files. The measurement excludes only this evidence-only commit and is above the 1,500-line soft cap because the directly proving shared/UI tests and the recovery ownership correction remain cohesive; splitting them would leave either an untested shell or a cross-layer recovery intent without its callers.

- Real cockpit ergonomics, helper/relay recovery, representative-plugin behavior, and mobile release-target interaction remain in user-run MT Gate C after slice 3.

## Acceptance

- [x] Bridge, Projects, and Settings remain reachable through a persistent desktop cockpit.
- [x] Wide project navigation preserves one session inventory while narrow navigation remains one-pane.
- [x] Cockpit and project recovery use one desktop-core helper-plus-relay recovery intent without mobile CLI guidance.
- [x] Desktop Enter sends, Shift+Enter inserts a newline, and active IME composition retains Enter.
- [x] Escape releases editing or dismisses only typed popup routes; ordinary pages remain intact.
- [x] Transcript/diff source selection excludes navigation and presentation-only file/gutter metadata.
- [x] Shared UI remains free of desktop dependencies and mobile behavior remains regression-clean.
- [x] Relevant analyzers, full suites, LSP diagnostics, clean macOS release build, codesign verification, and architecture review pass.
