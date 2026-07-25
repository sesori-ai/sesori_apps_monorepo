# Setup-Aware Plugin Management: Tracker

## Current State

- **Base:** `origin/main` at `41e03f12`
- **Current branch:** `setup-aware-plugin-management-resident-attach`
- **Current slice:** Stage 12-P01 / step 1 of 6
- **Next action:** monitor PR #563 through CI and review

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [ ] | P01 — attach-only residency and diagnostics | `setup-aware-plugin-management-resident-attach` | PR #563 open; monitoring |
| [ ] | P02 — read-only management snapshots | `setup-aware-plugin-management-read-snapshots` | waits for P01 merge |
| [ ] | P03 — revision and SSE invalidation | `setup-aware-plugin-management-invalidation` | waits for P02 merge |
| [ ] | P04 — live idle-timeout mutations | `setup-aware-plugin-management-idle-timeouts` | waits for P03 merge |
| [ ] | P05 — transactional plugin disable | `setup-aware-plugin-management-disable` | waits for P04 merge |
| [ ] | P06 — remaining commands and dynamic eligibility | `setup-aware-plugin-management-commands` | waits for P05 merge |

## Source Material

- Frozen PR #510: https://github.com/sesori-ai/sesori_apps_monorepo/pull/510
- Substantive old commit: `c4104e73`
- Blocked-setup fixture follow-up: `bf0433b8`
- Old size: 36 files, 3,286 additions, 228 deletions
- Never merge, rebase, or cherry-pick the frozen descendant stack. Reconstruct
  each behavior against current `main` and preserve newer lifecycle invariants.

## Review Record

- The first 2026-07-25 architecture pass rejected the specificity gate. The
  plan was expanded with every requested shared/client switch, settings method,
  runtime transaction signature, production consumer, route registration, and
  dynamic catalog data flow.
- The permitted specificity recheck passed its gate and rejected two choices.
  Removed the unused replay-latest management snapshot stream; synchronous GET
  state plus the revision stream are now the only read/change mechanisms.
- The other finding requested moving all pre-existing lifecycle construction
  from `BridgeRuntimeRunner` into `Orchestrator`. That considerable refactor is
  outside this management scope and would blur the current bootstrap/session
  phase boundary. P06 was narrowed instead: dynamic catalog validation uses the
  already-injected `CatalogImportRepository`, adding no new runner/orchestrator
  dependency. A composition-boundary refactor, if desired, belongs in a
  dedicated plan and PR.
- P01 architecture implementation review approved all 17 changed files with no
  findings. The generic descriptor policy, OpenCode-owned interpretation,
  lifecycle timeout ownership, and unchanged runtime boundary were accepted.

## Verification Log

### 2026-07-25 — P01 attach-only residency and diagnostics

- Added generic descriptor-declared transient/resident policy; OpenCode maps
  `--opencode-no-auto-start` to resident while every other descriptor inherits
  transient behavior.
- Lifecycle effective-timeout calculation now returns `0` for resident policy
  without changing the positive persisted timeout. Added regression coverage
  proving no idle timer or stop is scheduled while the stored value remains 45.
- Promoted plugin generation start tracing to debug and added start completion,
  command stop begin/completion, idle expiry, and recovered idle outcome logs.
- Focused interface descriptor tests passed (12), OpenCode descriptor tests
  passed (32), and bridge lifecycle/runtime/setup-route/recovery tests passed
  (50).
- `dart analyze --fatal-infos` passed sequentially in plugin interface,
  OpenCode, Codex, ACP, Cursor, and bridge app. `git diff --check` passed.
- Aristotle implementation review approved the complete working-tree diff with
  no architecture findings.
- Committed as `f0831886`, pushed, and opened PR #563 with the fixed step-1/6
  series title.

## Delivery Rules

- Use the exact title and fixed `1/6` through `6/6` order from `PLAN.md`.
- Start each branch from the latest merged predecessor on `origin/main`.
- Open only one replacement PR at a time after focused verification and
  architecture implementation review pass.
- Monitor each opened PR immediately and address review/CI before starting the
  next branch.
