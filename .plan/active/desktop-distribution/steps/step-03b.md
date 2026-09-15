# Step 3.b — Packaged Helper Repair Guidance

Status: **implemented; architecture implementation review pending**. PR ordinal
**4/13**, following merged [3.a](step-03.md). Work stays in `tan-antelope` on
`desktop-distribution-repair-guidance`.

## Behavior and ownership

- Foundation's `BridgeExecutableResolutionException.userMessage` is a safe
  presentation capability. The shell's bundle exception implements it while
  retaining the original error and installed path for local diagnostics.
- The existing `BridgeProcessService` publishes immutable
  `BridgeProcessStartFailed(message)` only after cleanup confirms no helper
  remains. The original error still reaches its caller; existing cancellation,
  pending-exit ownership and unrelated startup failures keep their behavior.
- The automatic-start observer logs a refusal without scheduling crash backoff.
  A focused exit-86 restart regression first reproduced the overwritten failure
  (`BridgeProcessCrashRetryScheduled`), then passed with this narrow correction.
- Existing cubit/tray state offers repair status and explicit Start. The cockpit
  renders restart/reinstall guidance with Retry; a later valid Start clears it.
  Hidden launch stays non-modal with a usable tray. The refusal notice does not
  offer child logs when no helper spawned; original failures remain in local
  application diagnostics.
- Exhaustive home/takeover consumers treat this as a settled, unspawned state.
  No new mutable production fields, timers, subscriptions, lifecycle owner, DI
  registration, generated source, database or wire contract. No plugin-specific
  logic or analytics event; this diagnostic adds no concrete product metric.

Cleanup assessment: no independent obsolete storage, API or listener was found.
The generic stopped fallback is replaced only for this typed refusal. No unrelated
lifecycle refactor or installer behavior is included.

## Focused verification

Pinned Flutter **3.47.4** / Dart **3.13.3**; logs are under ignored
`build/desktop-repair-evidence/`.

| Cwd | Command | Result |
|---|---|---|
| `client/module_desktop_core` | `dart test test/services/bridge_process_service_test.dart test/cubits/bridge_control/bridge_control_cubit_test.dart test/orchestration/desktop_bridge_takeover_orchestrator_test.dart --reporter expanded` | 73 passed |
| `client/desktop` | `flutter test test/core/platform/desktop_packaged_bridge_path_test.dart test/core/widgets/desktop_cockpit_shell_test.dart --reporter expanded` | All 18 resolver cases passed; the new widget fixture initially failed to emit its replacement state |
| `client/desktop` | `flutter test test/core/widgets/desktop_cockpit_shell_test.dart --reporter expanded` | All 19 passed after fixing the fixture to drive the existing cubit stream |
| `client/module_desktop_core` | `dart analyze --fatal-infos` | Passed |
| `client/desktop` | `flutter analyze --no-pub --fatal-infos` | Passed |

Resolver inputs did not change after their passing run. Final core and cockpit
runs include the automatic-restart correction and omit a misleading child-log
action. Coverage proves no spawn, control cleanup, replayed repair state, valid
explicit retry, tray guidance, safe presentation and non-modal hidden behavior.
The existing generic failure, cancellation, crash and takeover cases still pass.

## Review and release boundaries

The architecture plan was approved without findings in run
`5df8ad69-ea18-4776-8ddc-2335bdc28609`. The exit-86 observer correction stays in the
existing lifecycle owner and adds no coordination. Implementation review will use
this branch against its `575dd34dc322f88289efb68731482efe8885fa4b` base.

This is focused automated service/widget evidence, not installed native GUI,
signed installer, real package replacement or interactive six-platform QA. The
[regression document](../../../../docs/regression/desktop-bridge-supervision.md)
records those exploration paths. macOS packaging still requires signer access;
parent and platform public-release gates remain open.
