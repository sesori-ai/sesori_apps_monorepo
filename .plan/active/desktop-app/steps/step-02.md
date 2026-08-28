# Step 2 — Bridge process primitives

Date: 2026-08-28.

## Delivered

- Added `ControlMessage.shutdown` to the shared control protocol and routed it
  through the bridge's single inbound dispatcher to the composition-owned,
  graceful exit-0 path. `unregister_and_exit` reuses that clean-stop path after
  its unregister attempt.
- Added the desktop Layer-1 `BridgeProcessApi`: raw stdio/exit hand-off,
  non-positive-PID rejection, POSIX graceful signaling, Windows `taskkill /T`,
  and POSIX descendant-first process-tree kill.
- Added the sole Layer-2 `BridgeProcessRepository` boundary: one active child,
  exit events with an expected marker, and an idempotent atomic expected stop
  that marks before sending `shutdown`, falls back to POSIX SIGTERM when the
  channel is absent, waits beyond the bridge's complete teardown/backstop
  budget, bounds the force-kill command and exit wait, permits a failed stop to
  be retried while the child remains active, and tree-kills without losing the
  marker.
- Added desktop-owned rotating helper logs: a shell-provided application-support
  directory seam, Layer-1 `BridgeProcessLogStorage` with a 5 MiB active-file cap
  plus one rotation and POSIX 0700/0600 hardening, and Layer-2
  `BridgeProcessLogTracker` with malformed-UTF-8-tolerant continuous pipe drain,
  a last-200 ring buffer, snapshots, a bounded/batched persistence queue, and
  rate-limited persistence and overflow warnings.
- Registered the new boundaries in desktop phase-1 / desktop-core phase-4 DI
  and exported their public contracts.

No user-visible or database behavior changes in this step. The first real GUI
spawn and handshake remain step 3.

## Plan truth

Actual implementation complexity was revised from `⚙️` to `🚧`: the cohesive
change crosses a shared wire contract, bridge lifecycle composition, OS process
control, secure persistence, and desktop DI. The ~1.8k-line soft-cap overage is
recorded in `PLAN.md`; generated union code and focused primitive tests account
for the excess.

## Architecture implementation review

Approved 2026-08-28. The reviewer applied B-Client, B-Bridge, and B-Shared and
found no issues: dependency direction, lifecycle ownership, DI phase ordering,
and class cohesion all match the plan.

## Post-merge review follow-up

A late automated review arrived after the step PR merged. Its five findings are
addressed in a focused follow-up before step 3: the regression contract now
covers supervised shutdown and diagnostics; partial helper lines are bounded
before UTF-8 decoding; bootstrap token cancellation preserves a prior clean
stop; transient application-support lookup failures can retry; and POSIX force
stop now targets a helper-established process group instead of a process-table
snapshot. The focused architecture plan and implementation reviews approved
all B-Client/B-Bridge boundaries with no findings.

## Verification

- `client/module_desktop_core`: `dart analyze --fatal-infos` — clean.
- `client/module_desktop_core`: `dart test` — 77 tests passed.
- `shared/sesori_shared`: `dart analyze --fatal-infos` — clean.
- `shared/sesori_shared`: `dart test test/protocol/control_message_test.dart` —
  18 tests passed.
- `bridge/app`: `dart analyze --fatal-infos` — clean.
- `bridge/app`: dispatcher + token-service focused tests — 28 tests passed.
- Follow-up bridge process-group + runtime-decision tests — 14 tests passed;
  host-native CLI build succeeded and a supervised launch reached the expected
  refused control connection without a process-group FFI failure.
- `client/desktop`: `dart analyze --fatal-infos` and `flutter test` — 18 tests passed.
- Dart LSP: 0 diagnostics across 21 affected production files.
- Regenerated shared Freezed/JSON and desktop Injectable outputs with
  `build_runner`.

Windows and Linux process-tree branches are unit-covered; their real OS build
and execution evidence comes from desktop CI and later manual gates. No manual
supervision gate is due until step 7.
