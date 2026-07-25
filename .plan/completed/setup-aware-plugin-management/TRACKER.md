# Setup-Aware Plugin Management: Tracker

## Current State

- **Implementation base:** `origin/main` at P05 merge `92cbdf06`
- **Series state:** complete; final PR #572 merged as `6cedf5bd`
- **Follow-up:** address #573 in a focused change

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [x] | P01 — attach-only residency and diagnostics | `setup-aware-plugin-management-resident-attach` | PR #563 merged as `f8f05c33` |
| [x] | P02 — read-only management snapshots | `setup-aware-plugin-management-read-snapshots` | PR #567 merged as `19ca475a` |
| [x] | P03 — snapshot tokens and SSE invalidation | `setup-aware-plugin-management-invalidation` | PR #568 merged as `00a0da77` |
| [x] | P04 — live idle-timeout mutations | `setup-aware-plugin-management-idle-timeouts` | PR #569 merged as `583c91f2` |
| [x] | P05 — transactional plugin disable | `setup-aware-plugin-management-disable` | PR #570 merged as `92cbdf06` |
| [x] | P06 — remaining commands and dynamic eligibility | `setup-aware-plugin-management-commands` | PR #572 merged as `6cedf5bd` |

## Source Material

- Superseded PR #510 (closed):
  https://github.com/sesori-ai/sesori_apps_monorepo/pull/510
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
- P05 architecture implementation review approved all 16 changed files with no
  findings. Shared wire ownership, runtime transaction retention, repository and
  service sequencing, route registration, shutdown waiting, and the unchanged
  runner/orchestrator/shared-router boundaries were accepted.

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
- Pushed and opened PR #569 with the fixed step-4/6 series title; monitoring
  started immediately.

### 2026-07-25 — P05 transactional plugin disable

- Added the strict final-wire disable command, safe/force stop mode, and typed
  forward-safe conflict response. Exact `type: disable` serialization and
  decoding reject missing, unknown, and future command discriminators.
- Replaced runtime eligibility state with enabled/draining/disabled access
  gates. Disable preparation fences starts and acquisitions before checking
  safe-stop conflicts, retains transition ownership through persistence, and
  supports validated commit or rollback while shutdown waits for settlement.
- The lifecycle service joins equal per-plugin disable commands, rejects a
  different active mode, and uses P04's existing settings mutation tail for the
  latest-load/save step. Durable success commits runtime access and eligibility;
  failed persistence rolls back live access and returns an explicit failure.
- Added `POST /plugin/:id/command` to the existing shared router with typed 400,
  404, 409, and 500 mappings. Debug routing continues to reuse the same session
  router and lifecycle service.
- Correctness hardening covers foreign transition ownership, auth-loss cleanup,
  access refresh during draining, truthful stopping snapshots, and exact wire
  discrimination. Focused runtime, lifecycle, route, and Orchestrator tests
  passed (71); shared contract tests passed (8).
- `dart analyze --fatal-infos` passed in shared and bridge app;
  `git diff --check` passed. Aristotle approved the complete 16-file
  architecture-bearing scope with no findings.
- Committed the implementation as `32273ee0`, merged P04's `583c91f2`
  `origin/main` result in `2787c40c`, and retained the verified P05 side of the
  expected squash-history conflicts.
- Post-merge reverification passed the shared contract tests (8), focused
  runtime/lifecycle/route/Orchestrator tests (71), both fatal analyzers, and
  `git diff --check`.
- Pushed and opened PR #570 with the fixed step-5/6 series title; monitoring
  started immediately.
- Review hardening through `828c7a38` keeps invalid commit and rollback paths
  settled, reconciles service eligibility after fail-closed commit errors,
  removes the lifecycle route's bang operator, and switches runtime state
  derivation directly on the access gate. Focused tests and fatal analysis pass;
  CI passes 13/13 and Cubic approves the latest reviewed changes.

### 2026-07-26 — P06 remaining commands and dynamic eligibility

- Expanded the shared lifecycle command union with enable, restart, and refresh
  while preserving strict command discrimination and safe/force stop modes.
- Added per-slot setup-inspection revision and generation fencing. Disable,
  authentication loss, newer probes, and generation changes prevent stale setup
  results from restoring access or overwriting current state.
- Lifecycle commands now serialize per plugin: enable persists eligibility then
  inspects and starts only when ready; restart requires eligibility and inspects
  before restart; refresh inspects without starting. Ready-ID publication is
  deferred across failed starts so catalog hydration additions remain retryable.
- Catalog import validation now reads live runtime-backed eligibility while
  active imports remain cancellable after eligibility removal. The existing
  additions-only hydration listener imports a newly enabled ready plugin.
- Correctness review findings for fail-closed eligibility reconciliation,
  auth-loss access restoration, disabled-plugin cancellation, and generation
  fencing were fixed. The follow-up review reported no remaining findings.
- Shared contract tests passed (8), focused bridge tests passed (88), fatal
  analysis passed in shared and bridge app, and `git diff --check` passed.
  Aristotle approved the complete architecture-bearing P06 scope with no
  findings.
- Merged P05's `92cbdf06` `origin/main` result in `185197c0`, preserving the
  independently merged client SSE compatibility fix from PR #571. Post-merge
  verification passed the same 8 shared contract tests, 88 focused bridge
  tests, both fatal analyzers, and staged/unstaged diff checks.
- Pushed and opened PR #572 with the fixed step-6/6 series title; monitoring
  started immediately.
- Review follow-up `7473fcbd` keeps failed-start hydration readiness deferred
  across refresh and makes the new/modified lifecycle test helpers follow the
  required named-parameter convention. Focused service tests and fatal analysis
  passed; Cubic approved the updated head and CI passed 13/13.
- End-to-end verification used the PR iOS simulator build, production relay,
  and the source bridge with `--data-dir ~/.local/share/sesori-dev`. It covered
  all three real backend CLIs, live enable/disable/refresh/restart, equal-command
  joining and differing-command conflicts, malformed/unknown requests, dynamic
  defaults including zero eligible plugins, timeout override/apply-all writes,
  durable denylist/timeout state across bridge restart, mobile disconnect/re-key,
  an explicitly setup-blocked Codex runtime, explicit and automatic catalog
  hydration, durable catalog browsing while plugins were disabled, and mobile
  new-session eligibility after reopening.
- Created real OpenCode, Codex, and Cursor sessions in the permitted project
  `random stuff` and received exact backend replies without modifying files.
  Safe disable of busy Codex returned typed `409 busy`; OpenCode and Cursor
  completed overlapping turns, Codex restarted independently while OpenCode was
  active, and Cursor completed a turn while the app was backgrounded.
- Force disabling busy Codex stopped its runtime but left the client session and
  interrupted tool part marked `Running`. Re-enabling and sending another turn
  recovered the list-level session state, while the interrupted historical tool
  part remained stale. The demonstrated cross-layer reconciliation defect is
  tracked separately as [#573](https://github.com/sesori-ai/sesori_apps_monorepo/issues/573)
  rather than expanding P06.
- A stale New Session selection was rejected after Cursor became disabled and
  created no session. After a full source-bridge process restart, all three
  persisted sessions retained their backend bindings. Exact replies were
  `CODEX POST RESTART OK.`, `OPENCODE POST RESTART OK.`, and
  `CURSOR POST RESTART OK.`.
- Final management state has all plugins setup-ready, active, and idle, with
  OpenCode as default, the restored 10-minute default timeout, and no overrides.
  The restart log contains no failure, exception, or crash, and no new simulator
  crash appeared.
- PR #572 merged as `6cedf5bd` with 14/14 checks passing and zero unresolved
  review threads, completing the six-PR series.

## Delivery Rules

- Use the exact title and fixed `1/6` through `6/6` order from `PLAN.md`.
- Keep one open PR and one local successor. Cut the successor from the open
  PR's latest reviewed head, but do not open it until its predecessor merges.
- After the predecessor merges, merge updated `origin/main` into the successor,
  reverify, and open it. Only then begin the following local successor; never
  work more than one PR ahead.
- Monitor each opened PR immediately and address review/CI before starting the
  next branch's implementation.
