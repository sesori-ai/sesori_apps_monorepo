# Step 20 slice 2/3 — Desktop cockpit composition

- **Status:** `done`
- **Complexity:** `🚧`
- **User value:** Desktop users get a persistent cockpit shell with adaptive project/session navigation, truthful supervision recovery, desktop keyboard behavior, and usable source selection.
- **Dependencies:** Step 20 slice 1/3 (window bounds), Steps 14–19
- **Merged PR:** [#1269](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1269)
- **Pinned merged implementation head:** `51140cac2536ac747d7bc3141c33d585e5e8804b`

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
- The post-rebase patch ID remained unchanged (`691e7ffec3406091fd02e230cc47e3cc415439b6`) on top of merged PR #1267.
- A final bounded architecture review of the follow-up implementation range
  `2ac95d6644f92651e31687a37d715d40d4ce5fbf..72d06c995b8251dff7493f0659afb2584e16dac6` was also
  **APPROVED**. It covered route-visibility ownership and the shared source-selection boundary added in review fixes.

## Verification

- `client/module_core`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 1,485 tests.
- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 220 tests.
- `client/module_app_ui`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 282 tests.
- `client/module_prego`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 270 tests.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 106 tests.
- `client/app`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 661 tests.
- Dart LSP reports zero diagnostics across all 17 changed production Dart files.
- A clean `asdf exec flutter build macos` succeeds (65.8 MB reported by Flutter), and `codesign --verify --deep --strict` accepts the resulting app bundle.
- `git diff --check` passes.
- The final merged implementation range is
  `8781052afbb698507ead4f8ea74d3b73465012b8..51140cac2536ac747d7bc3141c33d585e5e8804b`. The base is the
  merged PR's first parent, so the measurement includes all PR #1269 review fixes without including intervening main
  work. The exact non-self-inclusive reproduction is:

```bash
base=$(git rev-parse 51140cac2536ac747d7bc3141c33d585e5e8804b^)
git diff --numstat "$base" 51140cac2536ac747d7bc3141c33d585e5e8804b \
  | awk '{ additions += $1; deletions += $2; files += 1 } \
      END { print files, additions, deletions, additions + deletions }'
# 46 1899 317 2216
```

The final squash contains 1,899 additions plus 317 deletions, or 2,216 changed lines across 46 files. It is above the
1,500-line soft cap because the directly proving shared/UI tests and recovery ownership correction remain cohesive;
splitting them would have left either an untested shell or a cross-layer recovery intent without its callers.

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
