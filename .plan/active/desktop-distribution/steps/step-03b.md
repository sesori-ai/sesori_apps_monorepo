# Step 3.b — Packaged Helper Repair Guidance

Status: **done**, merged in [PR #1495](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1495)
as `e853838ac29b5d829f13622702c5d47a74eaa829`. PR ordinal **4/13**, following
[3.a](step-03.md). Implemented in `tan-antelope` on `desktop-distribution-repair-guidance`.

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
`build/desktop-repair-evidence/`. These are local working-tree runs, not Actions
merge-checkout runs. **Final** means the implementation tree subsequently committed
as `bfd3693de3c00217c20b3ab81e40d205aed97d35`. **Intermediate** means the earlier
uncommitted implementation on base `575dd34dc322f88289efb68731482efe8885fa4b`:
there is no commit for that whole tree. Its resolver production/test files are
unchanged in `bfd3693`; the failed widget fixture and later automatic-restart
correction are not attributed to that earlier pass.

| Source | Cwd | Command | Result |
|---|---|---|---|
| Final | `client/module_desktop_core` | `dart test test/services/bridge_process_service_test.dart test/cubits/bridge_control/bridge_control_cubit_test.dart test/orchestration/desktop_bridge_takeover_orchestrator_test.dart --reporter expanded` | 73 passed |
| Intermediate | `client/desktop` | `flutter test test/core/platform/desktop_packaged_bridge_path_test.dart test/core/widgets/desktop_cockpit_shell_test.dart --reporter expanded` | All 18 resolver cases passed; the new widget fixture initially failed to emit its replacement state |
| Final | `client/desktop` | `flutter test test/core/widgets/desktop_cockpit_shell_test.dart --reporter expanded` | All 19 passed after fixing the fixture to drive the existing cubit stream |
| Final | `client/module_desktop_core` | `dart analyze --fatal-infos` | Passed |
| Final | `client/desktop` | `flutter analyze --no-pub --fatal-infos` | Passed |

Resolver inputs did not change after their passing run. Final core and cockpit
runs include the automatic-restart correction and omit a misleading child-log
action. Coverage proves no spawn, control cleanup, replayed repair state, valid
explicit retry, tray guidance, safe presentation and non-modal hidden behavior.
The existing generic failure, cancellation, crash and takeover cases still pass.

## Merge and CI closeout

Accepted PR head: `758bc5548219c08420d1cac86718b4d997de818c`. Final Cubic review
approved with no findings; all four documentation threads were resolved. Workflow
[34994634843](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34994634843)
passed analyzer/tests and macOS, Windows and Linux desktop build jobs. Its measured
Actions merge checkout was `c40323edd60873d0a7d6f498ab05c4c8fd2b798f`, not the PR
head or eventual squash. The supervised E2E job was intentionally skipped here;
3.a's six-target relocated-helper E2E remains separate evidence.

Checkout attribution was read from repository root with
`gh api --allow-escape-sequences repos/sesori-ai/sesori_apps_monorepo/actions/jobs/104467729892/logs`;
the checkout step's `git log -1 --format=%H` records that merge SHA. The captured
log is `build/desktop-repair-evidence/final-analyze-test-ci.log`.

## Review and release boundaries

The architecture plan was approved without findings in run
`5df8ad69-ea18-4776-8ddc-2335bdc28609`. The exit-86 observer correction stays in the
existing lifecycle owner and adds no coordination. Architecture implementation
review **approved without findings** in run `221a6f88-1e6a-4a7e-8a5b-67004f4d5f7c`:
commit `bfd3693de3c00217c20b3ab81e40d205aed97d35` against base
`575dd34dc322f88289efb68731482efe8885fa4b`, 17 paths and 325 authored changed lines.
It confirmed foundation/shell boundaries, existing lifecycle ownership, immutable
state and consumer projections, with no new coordination or architectural violation.
The report is retained as `reviews/desktop-distribution-step-03b-architecture.md`
in that run's bound subagent output. Only documentation changed after review.

Diff sizes are **additions plus deletions over the whole merge-base diff**, all
authored (zero generated), not commit-to-commit churn. Reproduce from repository
root with these fixed revisions; the three-dot form resolves their merge base:

```bash
git diff --numstat 575dd34dc322f88289efb68731482efe8885fa4b...bfd3693de3c00217c20b3ab81e40d205aed97d35
git diff --numstat 575dd34dc322f88289efb68731482efe8885fa4b...959094cb945d07073b280a3146c2c49c922d299c
```

The reviewed checkpoint is **294 additions + 31 deletions = 325**, across 17
paths. Initial published head `959094c` is **301 + 31 = 332**, also 17 paths:
its documentation-only review record adds seven lines to the aggregate PR diff.
These are two fixed historical measurements, not conflicting current-head totals.

This is focused automated service/widget evidence, not installed native GUI,
signed installer, real package replacement or interactive six-platform QA. The
[regression document](../../../../docs/regression/desktop-bridge-supervision.md)
records those exploration paths. macOS packaging still requires signer access;
parent and platform public-release gates remain open.
