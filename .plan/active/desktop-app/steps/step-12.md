# Step 12 — 🚧 Supervised E2E + harness retirement

Date: 2026-08-30.

## Scope

- Build a real native bundled bridge helper and exercise supervised control
  startup against loopback fake auth, relay, and GUI-control services.
- Cover the first token pull, authenticated bridge registration, relay auth,
  restart through the existing `/global/restart` route with exit 86, a fresh
  respawn using the same data directory, and `unregister_and_exit` with clean
  exit 0 and server-side deletion.
- Isolate HOME/USERPROFILE/LOCALAPPDATA/XDG paths and pre-seed settings so the
  test disables non-essential plugins, turns sleep prevention off, and never
  contacts production services.
- Run the native helper build and integration test on macOS, Windows, and Linux
  in Desktop CI, with failure diagnostics uploaded after redaction.
- Remove the obsolete interactive `bridge/app/tool/dev_control_host.dart`
  harness and reconcile regression documentation.

## Step 11 follow-up carried forward

The first commit on this branch (`ce83aaa557`) addresses the post-merge Codex
lifecycle findings from PR #1213: explicit stop-mode ownership for concurrent
ordinary/logout stops, an immediate ordinary shutdown fallback when unregister
cannot be delivered, and `/auth/me` verification for token-only local sessions.
The focused desktop-core tests cover those paths; the real helper E2E covers the
helper-side registration and unregister half of the flow.

## Implementation

`bridge/app/test/integration/supervised_e2e_test.dart` launches the bundled
helper, answers typed control token requests, validates fake-auth registration
and deletion requests, observes relay auth frames, invokes the real debug
restart route, and respawns with a fresh control secret. The fake servers bind
only to ephemeral loopback ports and the test always terminates remaining
process trees before removing its temporary directories.

`.github/workflows/desktop-ci.yml` adds a separate `supervised_e2e` path gate and
native three-OS matrix. The bridge workspace is resolved and built on each
runner; the terminal `status` aggregator includes the new job.

## Verification

- `bridge`: `dart pub get` completed; the native bundled helper was built with
  `dart build cli -o build/cli` on macOS.
- `bridge/app`: `dart analyze --fatal-infos` clean; full suite passed (2,777
  tests), including the required real supervised E2E test.
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; full suite
  passed (177 tests), including the carried stop-mode and token-only-session
  fixes.
- `client/desktop`: `flutter analyze --fatal-infos` clean; full suite passed
  (49 tests).
- `client/app`: `flutter analyze --fatal-infos` clean; full suite passed (913
  tests).
- `actionlint .github/workflows/desktop-ci.yml` and Dart LSP diagnostics for
  changed source/test files are clean; `git diff --check` is clean.
- Native three-OS CI passed in the merged Step 12 PR (#1215), with 19/19 CI
  checks green, including the real supervised E2E on macOS, Windows, and Linux.

## Handoff

Step 12 merged in PR #1215 on 2026-08-30. The user-run MT gate B daily-driver
matrix is the next manual checkpoint while Step 13 proceeds locally.
