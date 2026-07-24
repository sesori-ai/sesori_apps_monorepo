# Setup-Aware Transient Plugin Lifecycle: Tracker

## Plan State

- **Status:** Stage 10 merged; PR #508 frozen as reference; smaller replacement
  stack in progress
- **Base:** `origin/main` at `51008356`
- **Current branch:** `setup-aware-plugin-lifecycle-operation-routing`
- **Current stage:** Stage 11-P01B — plugin operation routing open as PR #548
- **Next action:** monitor #548 and propagate its merged-main synchronization through the successor stack

## Frozen Oversized Stack

PR #508 passed its verification but is too large to review effectively. It is
frozen at `f6cd675d` as source material while the behavior is rebuilt in smaller
PRs. Its descendants are not advanced until the replacement runtime boundary is
complete.

| Old PR | State | Replacement |
|---|---|---|
| #507 | Merged | Redesigned Stage 10, merged as `4ef55675` |
| #508 | Open, frozen | Oversized Stage 11-P01 reference at `f6cd675d`; replaced by P01A-P01D |
| #509 | Open, frozen | Dormancy descendant; rebuild/retarget after P01D |
| #510 | Open, frozen | Management descendant; rebuild/retarget after rebuilt dormancy stage |
| #511 | Open, frozen | Client descendant; rebuild/retarget after rebuilt management stage |

Old verification results are historical evidence only; replacement stages must
run their focused verification again.

## Replacement Stages

| Done | Stage | Branch | PR state |
|---|---|---|---|
| [x] | Stage 10 — setup discovery and denylist | `aware-plugin-lifecycle` | #507 merged |
| [x] | Stage 11-P01A — runtime mechanics | `setup-aware-plugin-lifecycle-runtime-mechanics` | #547 merged as `51008356` |
| [x] | Stage 11-P01B — plugin operation routing | `setup-aware-plugin-lifecycle-operation-routing` | #548 open and monitored |
| [ ] | Stage 11-P01C — dynamic events and durable fencing | `setup-aware-plugin-lifecycle-durable-events` | stack after P01B |
| [ ] | Stage 11-P01D — bridge-owned projects and defaults | `setup-aware-plugin-lifecycle-project-ownership` | stack after P01C |
| [ ] | Stage 11-P02 — dormancy and numeric idle timeout | rebuild branch TBD | frozen #509 descendant |
| [ ] | Stage 12 — headless management | rebuild branch TBD | frozen #510 descendant |
| [ ] | Stage 13 — redesigned mobile plugin settings | rebuild branch TBD | frozen #511 descendant |

## Locked Redesign Deltas

- Denylist is the sole persisted eligibility source.
- All plugin CLI options are registered; `--plugin` is removed.
- Setup inspection skips denied plugins and never installs.
- Setup adds `notInspected` and removes `canProvision`.
- Deterministic ordering replaces persisted order and bridge last-used; the
  derived default prefers OpenCode when selectable, then the first selectable
  plugin in display-name/ID order.
- Client stores last-used per bridge after the settings stage.
- Every ready plugin starts dormant.
- Idle configuration is integer minutes; `<= 0` never idle-stops after demand.
- Headless management removes authority/order/serialized enabled.
- Settings work targets the merged Prego Settings landing/sub-page architecture.
- No compatibility machinery is retained for any contract from the superseded
  oversized stack.
- Aggregate projects are bridge-owned and may include sessions from multiple
  plugins. Create/open/rename never select, start, acquire, or call a plugin.
- P01B may use one narrow stack-local live API view for consumers migrated in
  P01C/P01D plus a generation-dropping runtime-event adapter for existing
  listeners. Both are removed by P01D and are not released contracts.

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

### 2026-07-23 — frozen Stage 11-P01 reference

- PR #508 reached head `f6cd675d`, was synchronized through `main` at
  `583748ab`, and was mergeable with CI 10/10.
- The reference implementation contains the approved generation runtime,
  operation routing, durable fencing, bridge-owned projects, and
  OpenCode-preferred default behavior.
- Focused runtime/session/create, project/open/rename/activity, event/catalog,
  lifecycle/default, and routing verification passed; bridge-app
  `dart analyze --fatal-infos` passed.
- The implementation is frozen rather than rewritten because its 83-file,
  roughly 5.5k-addition diff is not reviewable as one PR.

### 2026-07-23 — Stage 11-P01A runtime mechanics

- Started a clean replacement branch from `origin/main` at `583748ab`.
- Added the concrete `PluginGenerationFactory` and `PluginRuntime` kernel plus
  focused runtime tests. The bridge composition remains unchanged in this slice.
- Focused generation-factory and runtime tests passed (40 tests).
- `dart analyze --fatal-infos` passed in `bridge/app`.
- Architecture implementation review approved the runtime/factory ownership,
  lifecycle, dependency direction, and enabling-slice boundary with no findings.
- Committed as `fbd02dee`, pushed, and opened as PR #547.
- PR review hardened generation-owned stream cancellation, command/disposal
  serialization, and access revocation. The second architecture pass identified
  a paused-consumer teardown dependency; source cancellation and lease release
  now complete without waiting for downstream `done` delivery.
- PR #547 merged into `main` as `51008356`; #548 was retargeted automatically
  and synchronized by merging that new `origin/main` head.

### 2026-07-23 — Stage 11-P01B operation routing

- Activated the generation runtime in bridge composition while preserving eager
  Stage 10 residency and alphabetical default behavior.
- Moved ordinary session, agent, provider, question, permission, and worktree
  backend calls behind typed runtime acquisitions. Session creation uses
  `useAndCommit` for its backend-result/binding transaction boundary.
- Added a stack-local live API view for remaining catalog/project consumers and
  adapted existing event listeners to the runtime event source without yet
  carrying generation into normalization.
- Focused lifecycle, repository, routing, runtime, orchestrator, debug-server,
  and shutdown suites passed (210 tests).
- `dart analyze --fatal-infos` passed in `bridge/app`.
- Architecture implementation review approved composition ownership, runtime
  routing, dependency direction, and both contained stack-local seams with no
  findings.
- Committed as `2e20026d`, pushed, and opened as stacked PR #548.

## Delivery Rules

- Start P01A from latest `origin/main`; stack P01B-P01D from each verified
  predecessor.
- Keep #508 frozen until replacement PRs exist; do not force-rewrite it.
- Rebuild or retarget #509-#511 only after P01D is complete.
- Open each replacement PR only after its focused checks pass, then monitor that
  PR immediately.
