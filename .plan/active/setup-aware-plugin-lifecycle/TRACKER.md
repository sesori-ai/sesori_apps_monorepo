# Setup-Aware Transient Plugin Lifecycle: Tracker

## Plan State

- **Status:** Stage 10 merged; Stage 11-P01 is being synchronized with `main`
  and corrected for bridge-owned aggregate projects
- **Base:** latest `origin/main`
- **Current branch:** PR branch `setup-aware-plugin-lifecycle-s11-p01`
  (local delivery branch `fix-p508-operation-enum`)
- **Current stage:** Stage 11-P01 / PR #508 conflict resolution and ownership fix
- **Next action:** finish focused verification and architecture review, merge any
  newer `main`, push #508, resolve its ownership thread, and monitor only #508

## Closed First Implementation

The first unmerged stack was closed before redesign:

| Old PR | State | Replacement |
|---|---|---|
| #507 | Merged | Redesigned Stage 10 |
| #508 | Open | Redesigned Stage 11-P01; current delivery focus and sole monitored PR |
| #509 | Open | Redesigned Stage 11-P02 stacked on #508 |
| #510 | Open | Redesigned Stage 12 stacked on #509 |
| #511 | Open | Redesigned Stage 13 stacked on #510 |

Old verification results are historical evidence only; replacement stages must
run their focused verification again.

## Replacement Stages

| Done | Stage | Branch | PR state |
|---|---|---|---|
| [x] | Stage 10 — setup discovery and denylist | `aware-plugin-lifecycle` | #507 merged |
| [x] | Stage 11-P01 — dynamic runtime boundary | `setup-aware-plugin-lifecycle-s11-p01` | #508 open; update in progress |
| [x] | Stage 11-P02 — dormancy and numeric idle timeout | `setup-aware-plugin-lifecycle-s11-p02` | #509 open |
| [x] | Stage 12 — headless management | `setup-aware-plugin-lifecycle-s12-p01` | #510 open |
| [x] | Stage 13 — redesigned mobile plugin settings | `setup-aware-plugin-lifecycle-s13-p01` | #511 open |

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
- Aggregate projects are always bridge-owned and may contain sessions from
  multiple plugins. Project create/open/rename never acquire or call a plugin;
  plugin observations remain evidence for bridge-owned activity/catalog state.

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

## Delivery Rules

- Start Stage 10 from latest `origin/main`; stack every later branch from its
  verified predecessor.
- Force-with-lease history rewrites are explicitly authorized for these closed
  branches.
- Reopen a PR only after its replacement stage is complete and focused checks
  pass.
- Start a PR monitor immediately after each PR is reopened.
