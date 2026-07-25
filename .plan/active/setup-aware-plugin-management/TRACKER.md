# Setup-Aware Plugin Management: Tracker

## Current State

- **Base:** `origin/main` at P03 merge `00a0da77`
- **Current branch:** `setup-aware-plugin-management-idle-timeouts`
- **Current slice:** Stage 12-P04 / step 4 of 6, verified against merged P03
- **Next action:** push and open the step-4/6 PR

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [x] | P01 — attach-only residency and diagnostics | `setup-aware-plugin-management-resident-attach` | PR #563 merged as `f8f05c33` |
| [x] | P02 — read-only management snapshots | `setup-aware-plugin-management-read-snapshots` | PR #567 merged as `19ca475a` |
| [x] | P03 — snapshot tokens and SSE invalidation | `setup-aware-plugin-management-invalidation` | PR #568 merged as `00a0da77` |
| [ ] | P04 — live idle-timeout mutations | `setup-aware-plugin-management-idle-timeouts` | verified against `00a0da77`; no PR |
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
  state plus the change-token stream are now the only read/change mechanisms.
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
- P02 architecture implementation review approved all 11 changed files with no
  findings. Shared wire ownership, lifecycle mapping, route registration, and
  the existing runner/orchestrator boundary were accepted.
- The initial P03 architecture implementation review approved all 17 changed
  files with no findings. Its revision and settled-publication design was later
  superseded while addressing PR review; the replacement token contract and
  publication semantics received the permitted second review.
- The final P03 architecture implementation review approved the replacement
  snapshot-token contract, cached snapshot/token coherence, independent
  per-change publication, and unchanged Orchestrator SSE ownership with no
  findings.
- P04 architecture implementation review approved all seven production files
  with no findings. Shared request ownership, settings preservation, lifecycle
  write sequencing, route mapping, and the existing shared-router boundary were
  accepted.

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

### 2026-07-25 — P02 read-only management snapshots

- Added forward-safe shared runtime/work enums and read-only plugin management
  response models, including effective timeout and persisted-override facts.
- Added `PluginLifecycleService.managementSnapshot` and registered
  `GET /plugin/management` on the shared session router used by relay and debug
  requests. The read path performs no probes, starts, stops, or writes.
- Shared contract tests passed (3) and focused bridge lifecycle, handler, and
  debug-router tests passed (31).
- `dart analyze --fatal-infos` passed in shared and bridge app.
  `git diff --check` passed.
- Aristotle implementation review approved the complete working-tree diff with
  no architecture findings.
- Committed locally as `b1b14d43`; merged P01 and `origin/main` into the
  successor after PR #563 merged.
- Reverification against merged P01 passed the shared contract tests (3),
  focused bridge lifecycle/handler/debug-router tests (31), fatal analysis in
  shared and bridge app, and `git diff --check`.
- Updated the `address-pr-comments` skill so the agent never resolves a thread
  containing human-authored review comments; only fully addressed AI-only
  threads may be resolved automatically.
- Pushed and opened PR #567 with the fixed step-2/6 series title; monitoring
  started immediately.

### 2026-07-25 — P03 snapshot tokens and SSE invalidation

- Added a backward-compatible opaque token to management snapshots and a typed
  `plugin.management.changed` SSE event.
- Lifecycle publication caches each materially changed public snapshot with a
  new random 128-bit token before synchronous notification. Transition states
  and unrelated plugin changes publish independently, and OrchestratorSession
  remains the sole SSE owner.
- Existing session-focused client consumers explicitly classify the event as
  global and ignore it until management state enters the client in a later
  slice.
- Shared management/SSE tests passed (43). Focused bridge lifecycle, handler,
  and Orchestrator coverage passed, including token deduplication, transient
  state, unrelated-plugin invalidation, and token/GET coherence. Affected
  module_core tests passed (108).
- Fatal analysis passed in shared, bridge app, module_core `lib`, and mobile app
  `lib`; `git diff --check` passed.
- The initial Aristotle implementation review approved the revision-based
  working-tree diff with no architecture findings. The permitted final review
  approved the replacement snapshot-token contract and publication semantics
  with no findings.
- Committed locally as `1940c969` after PR #567 merged.
- Pushed and opened PR #568 with the fixed step-3/6 series title; monitoring
  started immediately.
- Fixed CI initialization against partial runtime snapshots in `ec79f079` by
  waiting for complete management state before establishing the first baseline.
- Replaced revisions with opaque snapshot tokens and removed global transition
  suppression in `e764baa2`, addressing both Codex review findings. Both
  confirmed-Bot threads were replied to and resolved; refreshed CI passed 13/13
  and Cubic approved the reviewed head.
- PR #568 merged as `00a0da77` with 14/14 checks and zero unresolved threads.

### 2026-07-25 — P04 live idle-timeout mutations

- Added strict typed apply-all, set-override, and clear-override requests plus
  `PATCH /plugin/idle-timeout` on the existing shared router.
- Lifecycle writes reload, derive, and durably save settings inside one ordered
  mutation tail before resynchronizing timers or publishing a new management
  snapshot token.
- Apply-all clears overrides only for registered plugins, preserving unknown
  plugin entries and additional properties. Resident plugins retain effective
  timeout `0` while persisted overrides remain editable.
- Shared management contract tests passed (6), and focused bridge settings,
  lifecycle, handler, and Orchestrator tests passed (42).
- Fatal analysis passed in shared and bridge app; `git diff --check` passed.
- Aristotle implementation review approved the complete production diff with
  no architecture findings.
- Merged P03's `00a0da77` `origin/main` result into the local successor.
  Post-merge reverification passed the same shared tests (6), focused bridge
  tests (42), and fatal analyzers before the P04 PR opens.

## Delivery Rules

- Use the exact title and fixed `1/6` through `6/6` order from `PLAN.md`.
- Keep one open PR and one local successor. Cut the successor from the open
  PR's latest reviewed head, but do not open it until its predecessor merges.
- After the predecessor merges, merge updated `origin/main` into the successor,
  reverify, and open it. Only then begin the following local successor; never
  work more than one PR ahead.
- Monitor each opened PR immediately and address review/CI before starting the
  next branch's implementation.
