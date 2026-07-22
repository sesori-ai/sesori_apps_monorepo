# Setup-Aware Transient Plugin Lifecycle: Tracker

## Plan State

- **Status:** Stage 10 merged; Stages 11-13 remain open and monitored
- **Base:** synchronized with `origin/main` at `4ef55675`
- **Current branch:** `setup-aware-plugin-lifecycle-s13-p01`
- **Current stage:** Stage 13 delivered
- **Next action:** monitor CI and review activity across #508-#511

## Closed First Implementation

The first unmerged stack was closed before redesign:

| Old PR | State | Replacement |
|---|---|---|
| #507 | Merged | Redesigned Stage 10 merged to `main` as `4ef55675` |
| #508 | Reopened | Stage 11-P01 plus typed runtime operations at `6d0dce4f`; monitored |
| #509 | Reopened | Stage 11-P02 plus ACP authentication recovery at `757634a4`; monitored |
| #510 | Reopened | Stage 12 synchronized with #509 at `e0a92aeb`; monitored |
| #511 | Reopened | Stage 13 synchronized with #510 at `1837d1b0`; monitored |

Old verification results are historical evidence only; replacement stages must
run their focused verification again.

## Replacement Stages

| Done | Stage | Branch | PR state |
|---|---|---|---|
| [x] | Stage 10 — setup discovery and denylist | `aware-plugin-lifecycle` | #507 merged |
| [x] | Stage 11-P01 — dynamic runtime boundary | `setup-aware-plugin-lifecycle-s11-p01` | #508 open and monitored |
| [x] | Stage 11-P02 — dormancy and numeric idle timeout | `setup-aware-plugin-lifecycle-s11-p02` | #509 open and monitored |
| [x] | Stage 12 — headless management | `setup-aware-plugin-lifecycle-s12-p01` | #510 open and monitored |
| [x] | Stage 13 — redesigned mobile plugin settings | `setup-aware-plugin-lifecycle-s13-p01` | #511 open and monitored |

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
  `235589b3`.

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
- The replacement production implementation commit is `c0b3ed11`; it was
  force-pushed with lease and #509 was reopened using the same
  temporary-old-head GitHub workaround. The replacement code was restored
  immediately and monitored. The follow-up test-only code commit `1f5c7ea4`
  removes a stale activity-readiness wait exposed by CI. These hashes identify
  the production and test-code delivery, not the eventual PR head.
- Follow-up runtime-safety commits `8d4fc41e` and `f69f24dc` add cancellable
  idle timers and provisional work evidence for every accepted OpenCode/Codex
  turn before its request lease is released.
- Follow-up race fix `d4b3f1c1` prevents late accepted-turn responses and
  detached failures from corrupting provisional work evidence.

### 2026-07-20 — replacement Stage 12

- Added simplified shared management, command, conflict, numeric timeout, and
  `plugin.management.changed` contracts; regenerated Freezed/JSON outputs from
  source and updated only minimum client exhaustive SSE switches.
- Added explicit enabled/draining/disabled runtime access gates. Disable fences
  acquisitions before safe/force stop, commits the denylist only after teardown,
  and restores enabled+dormant without restart on persistence failure.
- Added Layer-3 command joining, serialized settings mutations, setup-inspection
  currency, replay-latest management snapshots, monotonic revisions, live
  enable/disable/restart/refresh, and numeric timeout updates.
- Added the three headless routes only: `GET /plugin/management`,
  `POST /plugin/:id/command`, and `PATCH /plugin/idle-timeout`. Relay and debug
  share the same router, and Orchestrator alone maps revisions to SSE.
- Kept one catalog hydration listener and made import eligibility live so newly
  enabled/ready plugins hydrate through the existing marker-before-acquisition
  path.
- Correctness audit findings were fixed: eligible enable retries inspect/start,
  routability requires start access, negative integer timeouts remain valid,
  apply-all preserves unknown plugin overrides, and fractional JSON timeouts
  are rejected rather than truncated.
- Sequential `dart analyze --fatal-infos` passed in `sesori_shared`,
  `bridge/app`, and `client/module_core`.
- Focused shared contract tests passed (9 tests); focused bridge runtime,
  lifecycle, handlers, catalog, hydration, Orchestrator, and debug tests passed
  (83 tests); affected module-core SSE tests and compilation passed.
- `git diff --check` passed.
- Committed as `c4104e73`, force-pushed with lease, and reopened #510 through
  the temporary-old-head GitHub workaround; the verified replacement head was
  restored immediately and is monitored.
- CI exposed a setup-route fixture that registered a setup-blocked plugin
  without a matching runtime snapshot. `bf0433b8` makes the test runtime model
  blocked setup honestly; the focused route test and bridge analyzer passed,
  and the rerun bridge test job passed. The remaining CLA failure is a GitHub
  503 after the action confirmed all contributors are signed.

### 2026-07-20 — replacement Stage 13

- Added nullable bridge identity to plugin discovery. New bridges return the
  registered bridge ID while older bridges decode as `null` without breaking
  discovery.
- Added module-core management transport, typed unsupported/not-found/conflict
  results, revision-monotonic orchestration, reconnect/SSE coalesced refresh,
  and explicit safe-to-force cubit state.
- Added secure per-bridge new-session plugin preferences through a dedicated
  API, repository, and `NewSessionPluginService`. Missing bridge identity skips
  persistence; read/write failures are logged and never block creation.
- Added the `/settings/plugins` Prego sub-page, a Plugins landing row, numeric
  global/per-plugin timeout controls, lifecycle actions, status presentation,
  and explicit force confirmation. No desktop route or screen was added.
- Generated shared Freezed/JSON, module-core Freezed/Injectable, and mobile
  localization outputs from source.
- Sequential `dart analyze --fatal-infos` passed in `sesori_shared`,
  `bridge/app`, `client/module_core`, `client/app`, and `client/desktop`.
- Focused shared/bridge contract and route tests passed; 97 focused module-core
  management, preference, reconnect, new-session, and route tests passed; 65
  focused mobile settings, new-session, and route tests passed. The final
  Plugins-copy regeneration was covered by 6 settings tests.
- Architecture review approved the combined Stage 13 working-tree scope with
  no findings. `git diff --check` passed.
- Committed as `167a3ee7`, force-pushed with lease, and reopened #511 through
  the temporary-old-head GitHub workaround; the verified replacement head was
  restored immediately and is monitored.
- After #507 squash-merged as `4ef55675`, merged `main` into #508 and propagated
  that merge through #509-#511 without rebasing. The only semantic conflict was
  Codex's transient work evidence against the newly merged session-layering
  architecture; the resolution preserved `CodexSessionService` ownership while
  retaining accepted-turn fencing and work-state publication. Codex analysis
  and all 36 focused plugin/write-path tests passed; bridge-app analysis and 71
  focused runtime/catalog/event tests passed; final module-core, mobile, and
  desktop analysis plus focused Stage 13 tests passed. #508-#511 are mergeable.
- Human review on #508 requested enum enforcement at the runtime acquisition
  boundary. `6d0dce4f` changes every `PluginRuntime` operation parameter to an
  enum-typed value and defers `.name` conversion to low-level errors/logging;
  domain repositories use scoped operation enums. Architecture review approved
  the change, bridge-app analysis and focused runtime/repository tests passed,
  and the merge was propagated through #509-#511.
- Review on #509 found that an ACP authentication failure retained a completed
  connection future and prevented recovery after local login. `757634a4`
  retains the typed failure but clears the connection attempt so the next call
  creates a fresh client. ACP analysis and focused initialize/authentication
  tests passed, and the fix was propagated through #510-#511.

## Delivery Rules

- Start Stage 10 from latest `origin/main`; stack every later branch from its
  verified predecessor.
- Force-with-lease history rewrites are explicitly authorized for these closed
  branches.
- Reopen a PR only after its replacement stage is complete and focused checks
  pass.
- Start a PR monitor immediately after each PR is reopened.
