# Step 11 — 🚧 Logout coordination + offline unregister fallback

Date: 2026-08-30.

## Delivered

- Added the authenticated `BridgeApi.deleteBridge()` / `BridgeRepository.deleteBridge()` path for `DELETE /auth/bridges/:bridgeId`. Bridge IDs are URL-encoded and an already-absent registration (`404`) maps to idempotent success.
- Added desktop-owned `BridgeIdStorage` under the existing `desktop-instance` application-data directory. `BridgeStatusTracker` persists each `registered` event with its owning account, serializes registration mutations, restores the record during dispatcher startup, and clears it only after confirmed server deletion for the currently authenticated owner.
- Added the typed `unregister_and_exit` command through `ControlCommandRepository` and `ControlCommandService`.
- Extended `DesktopLogoutOrchestrator` to persist durable Off, coordinate helper-side unregister with an expected stop, independently attempt GUI-side idempotent deletion only after verifying the current account owner (including token-only local restore), and then call `AuthSession.logoutCurrentDevice()` only after a successful helper stop. Delivery failures fall back to the ordinary expected shutdown; concurrent ordinary stops never receive a late unregister command. Deletion and helper-command failures remain observable but do not block offline local logout; a failed process stop retains authentication under the existing safety boundary.
- Updated desktop DI, startup ordering, regression documentation, and focused tests.

No database or new wire-contract change; the auth deletion endpoint and
`unregister_and_exit` protocol already existed. The change adds GUI persistence
and local logout sequencing.

## Architecture implementation review

The initial Step 11 architecture implementation review approved the original
implementation with no findings. A second review after the Codex follow-up
also approved the account-bound persistence record, owner-checked deletion,
and expected-stop-after-command path with no findings.

## Verification

- `client/module_core`: `dart analyze --fatal-infos` clean; full suite passed (1,463 tests), including bridge deletion and 404-idempotence coverage.
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; full suite passed (171 tests), including account-bound persisted registration, dispatcher startup, command routing, expected-stop teardown, and logout ordering/fallback coverage.
- `client/desktop`: `flutter analyze --fatal-infos` clean; full suite passed (49 tests).
- `client/app`: `flutter analyze --fatal-infos` clean; full suite passed (913 tests), confirming the shared module-core extension leaves mobile green.
- `dart pub get` and `dart run build_runner build` completed successfully for `module_desktop_core`; the typed persisted-registration model and DI config were regenerated.
- `git diff --check` clean.

## Handoff

Step 10 merged in PR #1212 and Step 11 merged in PR #1213 on 2026-08-30.
The post-merge Codex lifecycle findings are carried as the first focused commit
of the Step 12 branch, with targeted stop-mode and token-only-session coverage.
MT gate B remains the user-run daily-driver checkpoint after Step 12.
