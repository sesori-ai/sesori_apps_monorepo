# Setup-Aware Transient Plugin Lifecycle: Tracker

## Plan State

- **Status:** Stage 10 delivered; replacement stack rebuilding
- **Base:** `origin/main` at `5a91f582`
- **Current branch:** `aware-plugin-lifecycle`
- **Current stage:** Stage 11-P01 rebuild
- **Next action:** rebuild Stage 11-P01 from rewritten Stage 10, verify it,
  rewrite its branch, reopen #508, and start its monitor

## Closed First Implementation

The first unmerged stack was closed before redesign:

| Old PR | State | Replacement |
|---|---|---|
| #507 | Reopened | Redesigned Stage 10 at `794e853e`; CI/review monitored |
| #508 | Closed | Reopen after redesigned Stage 11-P01 is implemented and verified |
| #509 | Closed | Reopen after redesigned Stage 11-P02 is implemented and verified |
| #510 | Closed | Reopen after redesigned Stage 12 is implemented and verified |
| #511 | Closed | Reopen after redesigned Stage 13 is implemented on merged Settings architecture |

Old verification results are historical evidence only; replacement stages must
run their focused verification again.

## Replacement Stages

| Done | Stage | Branch | PR state |
|---|---|---|---|
| [x] | Stage 10 — setup discovery and denylist | `aware-plugin-lifecycle` | #507 open and monitored |
| [ ] | Stage 11-P01 — dynamic runtime boundary | `setup-aware-plugin-lifecycle-s11-p01` | #508 closed |
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

## Delivery Rules

- Start Stage 10 from latest `origin/main`; stack every later branch from its
  verified predecessor.
- Force-with-lease history rewrites are explicitly authorized for these closed
  branches.
- Reopen a PR only after its replacement stage is complete and focused checks
  pass.
- Start a PR monitor immediately after each PR is reopened.
