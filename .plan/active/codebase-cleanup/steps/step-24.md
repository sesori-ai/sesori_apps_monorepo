# Step 24 — Remove the migration-era dual-mode runtime knobs

`bridge/sesori_plugin_runtime` carried six switches that let one supervisor run
both a "legacy" and a "hardened" version of every start. The migration finished:
both shipping descriptors (Codex and OpenCode) select the hardened value for
every switch, so each one was a branch with a single reachable side.

## Re-verification against `main`

Checked before editing, because the plan's audit counts have been wrong before.

| Knob | Legacy default | Codex | OpenCode | Other production callers |
| --- | --- | --- | --- | --- |
| `RuntimeHealthPolicy.attemptCount` | — | never | never | none (3 test files only) |
| `preProbeBindable` | `false` | `true` | `true` | none |
| `failFastOnSpawnError` | `false` | `true` | `true` | none |
| `failOnEarlyChildExit` | `false` | `true` | `true` | none |
| `validateRuntime` | `null` | never set | never set | none (2 test files only) |

Commands used:

```bash
grep -rn --include="*.dart" "attemptCount\|validateRuntime\|preProbeBindable\|\
failFastOnSpawnError\|failOnEarlyChildExit" bridge/ client/ shared/
```

The `ManagedRuntimeSpec` comment still described serving "the legacy in-place
wrapper" and was rewritten.

## What changed

- **`RuntimeHealthPolicy` collapses from a sealed pair to one class.** The sealed
  hierarchy existed only to hold the legacy/hardened split; with `attemptCount`
  gone it wrapped a single variant. `HealthDeadlinePolicy` folds into
  `RuntimeHealthPolicy(deadline:, pollInterval:)` and the supervisor's
  `switch` over the pair becomes the loop it always ran in production.
- **`RuntimeRecordTiming` is deleted.** Both shipping plugins selected the same
  timing, so the branch had no production variation.
- **`preProbeBindable`, `failFastOnSpawnError`, `failOnEarlyChildExit` and
  `validateRuntime` are deleted**, each replaced by its single production value.

Net: **-150 lines in `lib/`**, -52 in `test/` (including a new 47-line shared
fake, so ~-99 of test churn removed).

## Behavior

Unchanged for both shipping plugins — every removed branch resolved to the value
Codex and OpenCode already passed. Two consequences worth stating explicitly:

- **A spawn error on the dynamic path propagates raw instead of being retried on
  the next candidate.** That was already production behavior via
  `failFastOnSpawnError: true`; only the deleted legacy path retried.
- **An abort that fires during a spawn that then fails surfaces the spawn's own
  error rather than `PluginStartAbortedException`.** Also already production
  behavior for the same reason. Every path where the spawn *succeeds* still
  settles aborts as `PluginStartAbortedException`.

## Tests

Two tests were removed because the change makes their premise unrepresentable,
not because they were inconvenient:

| Test | Why it cannot exist |
| --- | --- |
| `a failing validateRuntime rolls back the start` | `validateRuntime` no longer exists |
| `aborting settles as an abort even when the remaining candidates are all invalid` | needed the loop to continue past a spawn error, which only the legacy path did |

Reshaped rather than removed:

- `_spawned(...)` now defaults to `exitImmediately: false`. A child that exits
  before the first healthy probe is now always a failed start, so a test that
  wants a live runtime must have one; the three tests about early exit opt in
  explicitly.
- `_BindablePlan` answers "bindable" unless a test says otherwise. Every start
  pre-probes now, so requiring each test to declare the happy answer was noise;
  `probedPorts` remains the assertion surface.
- Tests whose start fails now wire `gracefulHooks[pid]`, because a live child
  has to actually stop for the rollback to complete. One delay assertion gained
  the graceful-shutdown wait that this makes observable.
- The shared `_healthPolicy` constant is `deadline: 1500ms / pollInterval: 500ms`.
  Most tests run on a clock that never advances, so the bound that fires is the
  poll backstop — `ceil(1500 / 500) + 2 = 5` — reproducing the five probes the
  old `attemptCount(attempts: 5)` gave them.
## Verification

```bash
cd bridge/sesori_plugin_runtime  && dart analyze --fatal-infos && dart test   # 127 passing
cd bridge/sesori_plugin_codex    && dart analyze --fatal-infos && dart test   # 392 passing
cd bridge/sesori_plugin_opencode && dart analyze --fatal-infos && dart test   # 434 passing
```

Repo-wide sweep confirms no remaining reference to any removed symbol:

```bash
grep -rn --include="*.dart" "HealthAttemptCountPolicy\|HealthDeadlinePolicy\|\
RuntimeRecordTiming\|validateRuntime\|failOnEarlyChildExit\|failFastOnSpawnError\|\
preProbeBindable\|recordTiming" bridge/ client/ shared/
```

Architecture implementation review: not run. No new or moved production class, no
DI change, no wire or persisted contract — this deletes parameters and their dead
branches inside one existing package.
