# Step 11 — 🚧 Logout coordination + offline unregister fallback

Date: 2026-08-30.

## Delivered

- Added the authenticated `BridgeApi.deleteBridge()` / `BridgeRepository.deleteBridge()` path for `DELETE /auth/bridges/:bridgeId`. Bridge IDs are URL-encoded and an already-absent registration (`404`) maps to idempotent success.
- Added desktop-owned `BridgeIdStorage` under the existing `desktop-instance` application-data directory. `BridgeStatusTracker` persists each `registered` event, serializes ID mutations, restores the ID during dispatcher startup, and clears it only after confirmed server deletion.
- Added the typed `unregister_and_exit` command through `ControlCommandRepository` and `ControlCommandService`.
- Extended `DesktopLogoutOrchestrator` to persist durable Off, request helper-side unregister, bounded-stop the helper through `BridgeProcessService`, independently attempt GUI-side idempotent deletion, and then call `AuthSession.logoutCurrentDevice()` only after a successful helper stop. Deletion and helper-command failures remain observable but do not block offline local logout; a failed process stop retains authentication under the existing safety boundary.
- Updated desktop DI, startup ordering, regression documentation, and focused tests.

No database or new wire-contract change; the auth deletion endpoint and
`unregister_and_exit` protocol already existed. The change adds GUI persistence
and local logout sequencing.

## Architecture implementation review

The Step 11 architecture implementation review approved the changes with no
findings. It confirmed the API → repository → service boundaries, focused
`BridgeIdStorage` ownership, dispatcher-before-restore startup ordering, and
`DesktopLogoutOrchestrator` lifecycle ownership.

## Verification

- `client/module_core`: `dart analyze --fatal-infos` clean; full suite passed (1,463 tests), including bridge deletion and 404-idempotence coverage.
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; full suite passed (165 tests), including persisted-id storage, dispatcher startup, command routing, and logout ordering/fallback coverage.
- `client/desktop`: `flutter analyze --fatal-infos` clean; full suite passed (49 tests).
- `client/app`: `flutter analyze --fatal-infos` clean; full suite passed (913 tests), confirming the shared module-core extension leaves mobile green.
- `dart run build_runner build` completed successfully for `module_desktop_core` and regenerated its DI config.
- `git diff --check` clean.

## Handoff

Step 10 merged in PR #1212. The successor branch is rebased onto the merged
`origin/main` and is ready to publish as the next plan-series PR. MT gate B
remains the user-run daily-driver checkpoint after Step 12.
