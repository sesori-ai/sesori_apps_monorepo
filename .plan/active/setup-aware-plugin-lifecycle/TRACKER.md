# Setup-Aware Transient Plugin Lifecycle: Tracker

## Plan State

- **Status:** Stage 11-P02 implemented and verified; delivery pending
- **Base:** `origin/main` at `5a91f582`
- **Current branch:** `setup-aware-plugin-lifecycle-s11-p02`
- **Current stage:** Stage 11-P02 delivery
- **Next action:** commit and force-push the verified Stage 11-P02 replacement,
  reopen #509, and start its monitor

## Closed First Implementation

The first unmerged stack was closed before redesign:

| Old PR | State | Replacement |
|---|---|---|
| #507 | Reopened | Redesigned Stage 10 at `794e853e`; CI/review monitored |
| #508 | Reopened | Redesigned Stage 11-P01 at `29472036`; CI/review monitored |
| #509 | Closed | Reopen after redesigned Stage 11-P02 is implemented and verified |
| #510 | Closed | Reopen after redesigned Stage 12 is implemented and verified |
| #511 | Closed | Reopen after redesigned Stage 13 is implemented on merged Settings architecture |

Old verification results are historical evidence only; replacement stages must
run their focused verification again.

## Replacement Stages

| Done | Stage | Branch | PR state |
|---|---|---|---|
| [x] | Stage 10 — setup discovery and denylist | `aware-plugin-lifecycle` | #507 open and monitored |
| [x] | Stage 11-P01 — dynamic runtime boundary | `setup-aware-plugin-lifecycle-s11-p01` | #508 open and monitored |
| [ ] | Stage 11-P02 — dormancy and numeric idle timeout | `setup-aware-plugin-lifecycle-s11-p02` | #509 closed |
| [ ] | Stage 12 — headless management | `setup-aware-plugin-lifecycle-s12-p01` | #510 closed |
| [ ] | Stage 13 — redesigned mobile plugin settings | `setup-aware-plugin-lifecycle-s13-p01` | #511 closed |

## Locked Redesign Deltas

- Denylist is the sole persisted eligibility source.
- All plugin CLI options are registered; `--plugin` is removed.
- Setup inspection skips denied plugins and never installs.
- Setup adds `notInspected` and removes `canProvision`.
- Alphabetical ordering/default replaces persisted order and bridge last-used.
- Client stores last-used per bridge after the settings stage.
- Every ready plugin starts dormant.
- Idle configuration is integer minutes; `<= 0` never idle-stops after demand.
- Headless management removes authority/order/serialized enabled.
- Settings work targets the merged Prego Settings landing/sub-page architecture.
- No compatibility machinery is retained for any contract from the closed
  unmerged stack.

## Review

- The original plan had two reviews before the redesign.
- 2026-07-19 redesign review pass 1 failed the specificity gate; the plan was
  expanded with concrete workspaces, files, classes, flows, and constructors.
- 2026-07-19 permitted specificity recheck passed the gate and rejected six
  architecture choices. Applied directly without another review: concrete
  `PluginRuntime` and `PluginGenerationFactory`, explicit disable access-gate
  transitions instead of a persistence callback, Stage-11 hydration listener
  ownership, and Layer-3 `NewSessionPluginService` preference coordination.

## Verification Log

### 2026-07-19 — replacement Stage 10

- Regenerated `sesori_shared` Freezed/JSON outputs from source with
  `dart run build_runner build`.
- Sequential `dart analyze --fatal-infos` passed in `shared/sesori_shared`,
  `bridge/sesori_plugin_interface`, `bridge/sesori_plugin_runtime`,
  `bridge/sesori_plugin_opencode`, `bridge/sesori_plugin_codex`,
  `bridge/sesori_plugin_cursor`, and `bridge/app`. The runtime and app analyzers
  were rerun after final review fixes and passed.
- Focused shared setup-wire tests passed.
- Focused interface descriptor/setup tests passed.
- Focused existing-runtime resolution/version and cooperative-abort tests passed.
- Focused OpenCode, Codex, and Cursor setup/availability tests passed.
- Focused bridge settings/repository/config-command, CLI parser/registry,
  setup-route, lifecycle, runtime-startup, routing, and zero-plugin tests passed.
- A correctness-only static diff review found explicit-null fail-open parsing,
  missing runtime-resolution abort checks, and empty plugin-ID acceptance. All
  three findings were fixed with regression coverage.
- `git diff --check` passed.
- Squashed onto `9e1625d0` as `d02f18d8`, force-pushed with lease, and
  reopened #507. Because GitHub refuses to reopen a closed PR after its head is
  rewritten, the old head was restored only long enough to reopen the PR, then
  the verified replacement head was restored immediately.
- Rebased cleanly onto `origin/main` at `5a91f582` on 2026-07-20; the Stage 10
  production commit is now `794e853e`.

### 2026-07-19 — replacement Stage 11-P01

- Replaced the replayed runtime interfaces with concrete `PluginRuntime`,
  `PluginGenerationFactory`, and `PluginLifecycleRepository` ownership.
- Migrated plugin-backed repositories, event listeners, orchestration, startup,
  tests, and benchmarks to generation-scoped acquisitions while preserving
  eager startup for every eligible, setup-ready, available plugin.
- A correctness-only static diff review found three issues: relay-routed work
  was abandoned during shutdown, backend-event generation attribution was lost
  before asynchronous normalization, and catalog publication lacked a final
  generation fence. All three were fixed, with stale-event and stale-catalog
  regression coverage.
- `dart analyze --fatal-infos` passed in `bridge/app` on the final production
  inputs.
- Focused runtime, event normalization/tracking, catalog import, orchestrator
  event-ordering, shutdown-drain, and error-recovery tests passed (62 tests).
- Earlier replacement verification also passed the wider repository/listener/
  routing suites and the three-plugin startup benchmark; those inputs were not
  changed by the final correctness fixes.
- `git diff --check` passed.
- Committed as `bc7d62b1`, force-pushed with lease, and reopened #508. GitHub
  again required temporarily restoring the old head solely for the reopen;
  `bc7d62b1` was restored immediately and is the monitored replacement head.
- Follow-up review fixes fenced activity, catalog, and session projection writes
  at their durable transaction boundaries and distinguished status-only stopping
  from command-owned teardown. After rebasing onto the synchronized Stage 10,
  the Stage 11-P01 production commit is `29472036` and current head is
  `66db912b`.

### 2026-07-20 — replacement Stage 11-P02

- Added replay-latest plugin-owned idle/busy/unknown work state and typed
  authentication-loss signaling across the interface, OpenCode, Codex, ACP,
  and Cursor's inherited ACP path.
- Extended concrete `PluginRuntime` with work-state observation, safe-stop
  gates, authentication fencing, lease draining, and repository-mapped idle
  policy inputs while keeping denylist ownership outside runtime mechanics.
- Switched every setup-ready available plugin to dormant startup and wired the
  existing numeric `idleTimeoutMins` settings so positive values schedule a
  full safe-stop timer and non-positive values never auto-stop after demand.
- Added lifecycle-owned ready-plugin snapshots and
  `PluginCatalogHydrationListener` as the sole automatic import trigger. Marker
  checks remain before runtime acquisition; headless imports remain explicit.
- Removed startup/reconnect backend activity enumeration while preserving
  event-driven durable activity updates.
- Architecture review findings were fixed: ACP replay preserves typed auth
  failures, obsolete eager-start surfaces and unused generation mapping were
  removed, and lifecycle idle policy now consumes repository-owned settled/
  safe-stop contracts instead of mechanical runtime command types.
- Sequential `dart analyze --fatal-infos` passed in
  `sesori_plugin_interface`, OpenCode, Codex, ACP, Cursor, and `bridge/app` on
  the final combined inputs.
- Focused interface/backend work-state and auth tests passed. Final bridge-app
  runtime, lifecycle, hydration, catalog, event projection, and orchestrator
  verification passed (80 tests), as did the three-plugin startup benchmark.
- Rebased the open Stage 10 and Stage 11-P01 branches, and this in-progress
  branch, onto `origin/main` at `5a91f582` as requested.
- `git diff --check` passed.

## Delivery Rules

- Start Stage 10 from latest `origin/main`; stack every later branch from its
  verified predecessor.
- Force-with-lease history rewrites are explicitly authorized for these closed
  branches.
- Reopen a PR only after its replacement stage is complete and focused checks
  pass.
- Start a PR monitor immediately after each PR is reopened.
