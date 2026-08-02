# Current-Branch Pull Request Monitoring: Tracker

## Current State

- **Plan slug:** `session-pull-request-monitoring`
- **Implementation base:** `main` at
  `f6ec9e9dc66782197a46261de3bcc002e261a5bd`
- **Series state:** Steps 1/9, 2.a–2.c/9, and 3/9 merged; Step 4 is in review
- **Current step:** Step 4/9 — current-branch request refresh
- **Plan PR:** [#649](https://github.com/sesori-ai/sesori_apps_monorepo/pull/649) merged
- **Superseded prototype:** [#659](https://github.com/sesori-ai/sesori_apps_monorepo/pull/659) closed
- **Next action:** monitor Step 4 PR #686 and address CI/review feedback

## Existing Baseline

- Implementation PR [#457](https://github.com/sesori-ai/sesori_apps_monorepo/pull/457)
  merged additive `RelayProjectView` and `Session.pullRequestHistory` contracts.
  Those compatible contracts are the starting point for this nine-step series.
- Parallel plugins are complete through PR #497.

## Plan Review

- **Verdict:** approved with no findings
- **Reviewer:** `aristotle-plan-review`
- **Reviewed scope:** complete current `PLAN.md`, `TRACKER.md`, and
  `CONSIDERATIONS.md`, against audited `main` at
  `83518cc0e7d0a2f0be50ba7ec6a866f6cbf79c44`
- **Date:** 2026-07-31
- **Findings applied:** none; pre-review gate and bridge/client/shared
  architecture all passed
- **Post-review drift:** `main` advanced through Harness settings, output-image
  plugin work, analytics documentation, bridge `--data-dir` expansion, and plan
  archival. The current tip is audited at `10c7afb9`; none changes this feature's
  architecture or requested agent guidance, so metadata/path refresh did not
  trigger another architecture review.

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/9 | `plan/session-pull-request-monitoring/replan-current-pr-only` | `🌿 [session-pull-request-monitoring] docs: plan current PR monitoring [step 1/9]` | 4,000–7,000 | [PR #649](https://github.com/sesori-ai/sesori_apps_monorepo/pull/649) merged as `f969754b` |
| [x] | 2.a/9 | `session-pull-request-monitoring-scoped-source` | `⚙️ [session-pull-request-monitoring] feat(bridge): scope GitHub PR queries [step 2.a/9]` | 500–900 | [PR #662](https://github.com/sesori-ai/sesori_apps_monorepo/pull/662) merged as `057e4c24` |
| [x] | 2.b/9 | `session-pull-request-monitoring-scoped-pr-persistence` | `🚧 [session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2.b/9]` | 9,800–10,800 | [PR #671](https://github.com/sesori-ai/sesori_apps_monorepo/pull/671) merged as `e6001fdc` |
| [x] | 2.c/9 | `session-pull-request-monitoring-scoped-pr-reads` | `🚧 [session-pull-request-monitoring] feat(bridge): gate scoped PR reads [step 2.c/9]` | 1,200–1,700 | [PR #678](https://github.com/sesori-ai/sesori_apps_monorepo/pull/678) merged as `d13cc8ca` |
| [x] | 3/9 | `session-pull-request-monitoring-graphql-selection` | `🚧 [session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]` | 3,100–3,500 | [PR #685](https://github.com/sesori-ai/sesori_apps_monorepo/pull/685) merged as `f6ec9e9d` |
| [ ] | 4/9 | `session-pull-request-monitoring-current-branch-refresh` | `🚧 [session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]` | 3,600–3,900 | [PR #686](https://github.com/sesori-ai/sesori_apps_monorepo/pull/686) open; all review feedback addressed with no unresolved threads |
| [ ] | 5/9 | `session-pull-request-monitoring-view-scheduler` | `🚧 [session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]` | 900–1,400 | Blocked on Step 4 merge |
| [ ] | 6/9 | `session-pull-request-monitoring-bridge-settings` | `⚙️ [session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]` | 1,000–1,500 | Blocked on Step 5 merge |
| [ ] | 7/9 | `session-pull-request-monitoring-client-presence` | `🚧 [session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]` | 1,000–1,500 | Blocked on Step 6 merge |
| [ ] | 8/9 | `session-pull-request-monitoring-client-settings` | `🚧 [session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]` | 1,000–1,500 | Blocked on Step 7 merge; use current settings owner and merged #647 pattern |
| [ ] | 9/9 | `session-pull-request-monitoring-retire-plan` | `🌱 [session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]` | 50–200 | Blocked on Step 8 merge |

## Exact PR Titles

1. `🌿 [session-pull-request-monitoring] docs: plan current PR monitoring [step 1/9]`
2.a. `⚙️ [session-pull-request-monitoring] feat(bridge): scope GitHub PR queries [step 2.a/9]`
2.b. `🚧 [session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2.b/9]`
2.c. `🚧 [session-pull-request-monitoring] feat(bridge): gate scoped PR reads [step 2.c/9]`
3. `🚧 [session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]`
4. `🚧 [session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]`
5. `🚧 [session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]`
6. `⚙️ [session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]`
7. `🚧 [session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]`
8. `🚧 [session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]`
9. `🌱 [session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]`

## Execution Rules

- Merge in numeric/substep order. Each implementation step starts from current `main`
  after its predecessor merges and records a drift audit.
- Step 1 is the plan PR. Step 9 moves the plan from active to completed and has
  no production changes.
- Keep each fixed complexity emoji in its exact title unless implementation
  evidence requires a plan/tracker update before opening that PR.
- Every PR body includes complexity/rationale, what, why, risk/test focus, and
  expected user-visible/data/internal results.
- Target 1,500 changed lines per implementation PR. Record actual additions plus
  deletions, generated output, tests, and any unavoidable overage.
- Do not combine adjacent steps merely because one lands below estimate.
- Every schema change exports/generates from current `main`; never rewrite a
  merged Drift migration or generated file.
- Run directly relevant tests/analyzers and architecture implementation review
  for Steps 2.a–8. Documentation-only Steps 1/9 and 9/9 use plan/docs validation.
- Reassess causal cleanup in every implementation step; remove directly obsolete
  code/data/tests in the coherent owning PR or record why removal is deferred.
- After each merge, update this tracker in the next step and proceed in order
  unless a material decision or blocker requires the user.

## Current Drift and Open Work

- Latest audited `main`: Step 4 branched from merged Step 3 at `f6ec9e9d`.
  Intervening image-viewer work does not overlap this bridge current-branch
  refresh scope.
- Drift schema: v13 on `main`; Step 4 leaves the merged schema and migration
  unchanged.
- Parallel-plugin plan: complete through Stage 9 / PR #497.
- PR #647 is merged and consolidates Harness settings into one screen. Its
  numeric-input/mutation pattern is current evidence for Step 8; PR cadence
  remains a separate bridge setting.
- Open PR #641 is analytics warehouse-only and does not change this feature's
  no-new-event decision.
- Open PR #621 touches the settings landing screen and may require Step 8 drift
  reconciliation if it merges.

## Interview Decisions Recorded 2026-07-31

- Root sessions only; child sessions have no independent PR.
- Dedicated and non-dedicated sessions both use the exact current branch.
- Sessions sharing a directory share current branch/PR state.
- Match any author in the same repository; fork heads are excluded.
- Newest open PR wins, otherwise newest merged/closed PR.
- A branch switch with no PR shows no PR and never falls back.
- Do not retain visited branches, multiple PRs, or PR history.
- Resolve branches only during activation/scheduled/explicit refresh; no
  filesystem watchers.
- Refresh only while project list/detail is viewed, plus explicit old-client
  request triggers.
- Multiple devices may view different projects; one connection owns one project
  and the bridge refreshes their active union.
- One fixed bridge interval defaults to 30 seconds and is customisable in
  seconds through bridge JSON plus shared client settings.
- App settings update the timer live; manual JSON edits require restart.
- Archive has no special PR behavior.
- No unseen mutation, push notification, history UI, desktop-shell-specific
  code, or new analytics event.
- Step 1 raises this plan; Step 9 moves it to `.plan/completed/`.

## Verification Log

- **Step 1/9:** `aristotle-plan-review` approved the complete production plan
  with no findings. The plan consolidation remains within its recorded
  4,000–7,000 changed-line target. No Dart/Flutter suite applies to this
  documentation/agent-definition PR.
- **PR #649 review follow-up:** Assessed five unresolved automated-review
  threads. All five identified concrete plan defects; the plan now covers
  fork-obscured candidate pagination, add-during-flight scheduling, read-time
  identity gating, named non-GitHub branch display, and the correct reviewed
  baseline SHA. Documentation validation remains `git diff --check`; no product
  suite applies.
- **PR #649 refresh-generation follow-up:** A later automated review correctly
  identified that a same-project explicit refresh could share an in-flight cycle
  after its local Git snapshot. The plan now seals per-project request
  generations before local resolution and requires post-seal requests/waiters to
  use the coalesced follow-up generation.
- **PR #649 route-visibility follow-up:** A later automated review correctly
  identified that GoRouter shell providers can remain mounted under covered
  child routes. Client claims now carry explicit visibility from `RouteSource`
  plus actual wide split-pane presence; hidden claims clear before disposal and
  are not reasserted on resume.
- **PR guidance update:** Added the requested `🌱`–`🚨` title scale,
  required PR-body summaries, and feature cleanup assessment/execution rules to
  Plan Maker and Plan Worker, with matching title/body rules in root
  `AGENTS.md`. These non-production instructions do not change the approved
  architecture. `git diff --check` passes, exact titles match between
  plan/tracker, and change scope is limited to this plan plus the three
  instruction/agent files.
- **Step 2 prototype and split:** PR #659 proved the end-to-end implementation
  and passed bridge tests/review fixes, but its 6,848 changed lines exceeded the
  1,500-line soft cap. It was closed without force-pushing. Step 2 is now split
  into source (2.a), persistence/migration (2.b), and fresh reads (2.c). The
  generated migration bundle still makes 2.b an unavoidable documented overage;
  separating it from its required writer/tests would create an untestable or
  non-compiling intermediate state.
- **Step 2.a/9 local verification:** `dart analyze --fatal-infos` and the focused
  `GhCliApi`, `PrSourceRepository`, and `PrSyncService` suites pass (43 tests).
  `git diff --check` passes. The 883 changed lines remain inside the 500–900
  target, including plan/tracker drift updates and tests.
- **Step 2.a/9 architecture review:** Aristotle rejected duplicate identity
  canonicalization in the initial API/repository models. The API model now owns
  only raw typed CLI output; `PrSourceRepository` exclusively trims, validates,
  and canonicalizes `VerifiedGithubLogin`. The required finding was addressed;
  repository policy does not re-review direct corrections.
- **PR #662 review follow-up:** Corrected stale delivery/overage wording, generated
  the raw API identity as a Freezed model, made identity failures and timeouts
  user-visible without claiming cached metadata is hidden, and fixed the new test
  helper signature. Follow-up review preserved nonzero command failures and pinned
  selectors to `github.com`, while reconciling the plan/tracker state. The approved
  `/9` denominator remains because 2.a–2.c are ordered substeps of the fixed
  nine-step sequence, not new top-level steps.
- **Step 2.a/9 merge:** PR #662 merged as `057e4c24`. Step 2.b starts from
  current `main` at `3f9a2980`, which also includes the unrelated voice-recorder
  prewarming work from PR #667; that drift does not overlap PR persistence.
- **Step 2.b/9 focused verification:** Drift/database/FK, repository/service,
  catalog, session enrichment, routing, and debug-server suites pass (237 tests),
  and the complete bridge app suite passes (2,291 tests). `dart analyze
  --fatal-infos` and `git diff --check` also pass. The initial PR diff was
  10,134 changed lines: 8,754 generated and 1,380 hand-authored. The generated
  total includes 6,841 lines of required v12/v13 migration helpers and the 1,137-line
  v13 schema snapshot; a separate helper-only PR would not be independently useful.
- **Step 2.b/9 cleanup assessment:** The v13 migration deletes the obsolete
  unscoped ephemeral PR cache instead of retaining ambiguous rows, all unscoped
  DAO/writer APIs update in place, and the obsolete create-session PR fixture was
  removed. No further directly caused cleanup was found; creation-branch state
  remains required for worktree cleanup, and Step 3 still owns removal of the
  repository-wide PR source.
- **Step 2.b/9 architecture review:** `aristotle-impl-review` approved the complete
  uncommitted working tree against `origin/main` with no findings. It confirmed
  the Drift migration, scoped joins, repository-owned transactions, service
  adaptation, catalog preservation, and orchestration wiring maintain the bridge
  layer and ownership rules without pulling Steps 2.c–4 forward.
- **PR #671 review follow-up:** Addressed all 12 initial bot threads by clearing
  stale scope during session rekeys, removing prior-account rows, preventing PR
  refresh from fabricating catalog projects, emitting/debouncing rendered scope
  invalidations, and preserving cache on typed transient Git failures. The
  second and final `aristotle-impl-review` approved the follow-up with no findings.
  Fatal-info analysis, all 2,297 bridge app tests, and `git diff --check` pass.
  After that round the 10,481-line PR contained 8,754 generated and 1,727 hand-authored
  lines; the 227-line hand-authored soft-cap overage is the coupled correctness
  response to review and cannot be separated without leaving known persistence
  and update-delivery defects in this PR.
- **PR #671 nested-worktree follow-up:** Two later bot threads correctly found
  that exact `projectPath/.git` detection regressed projects nested inside an
  enclosing worktree. Remote discovery now accepts Git metadata at any ancestor
  while retaining typed process failures; fatal-info analysis, 98 focused Git,
  source, project, and sync tests, and `git diff --check` pass. After that follow-up the PR was
  10,517 lines: 8,754 generated and 1,763 hand-authored.
- **PR #671 final review hardening:** Review rounds correctly identified
  symlink/discovery failures, departed and child-only branches, unchanged retries,
  and delayed invalidations. Git now uses locale-stable discovery, treats missing
  directories as absence, and surfaces other failures; cache scope is root-only
  and invalidations precede queries. Requests to retain cache with no root branch
  or discover repository identity during create were declined because both would
  violate authoritative scope ownership. The previous 2,301-test full suite,
  latest 51 focused tests, fatal-info analysis, and `git diff --check` pass; the
  final 10,743-line PR contains 8,754 generated and 1,989 hand-authored lines.
- **Step 2.b/9 merge:** PR #671 merged as `e6001fdc` with all 12 checks passing
  and no unresolved review threads. Step 2.c started immediately from that
  merged `main` tip.
- **Step 2.c/9 implementation:** List and detail reads now obtain fresh typed
  GitHub identity evidence before PR enrichment; DAO joins require that login
  alongside persisted project, row, repository, and branch scope. Unknown or
  switched identity yields sessions without PR metadata, and enrichment clears
  incoming PR/history data before applying the selected row. Waited refresh
  failures and timeouts return the original PR-free catalog snapshot.
- **Step 2.c/9 verification and review:** Fatal-info analysis and the pre-review
  full bridge app suite of 2,309 tests pass. Focused DAO/repository,
  identity-gated list/detail, refresh, mutation-response, SSE, integration, and
  benchmark contract suites also pass, as does `git diff --check`.
  `aristotle-impl-review` rejected handler-owned
  response mapping; the valid finding was applied by keeping authoritative
  PR/history clearing solely in `SessionRepository`, with no policy re-review.
  Automated review follow-up placed initial/final identity and mapping inside one
  five-second deadline, converts asynchronous refresh errors into explicit
  failure, and distinguishes an active refresh from completion. A later round
  bounded detail-read identity checks and made an unavailable waited-refresh
  source fail closed; the non-waiting list deadline remains intentional because
  it bounds the fresh identity gate rather than waiting for background refresh.
  Post-follow-up fatal-info analysis and the latest 59 focused
  handler/service tests pass. The approximately 1,170-line change remains below
  estimate because it reuses the Step 2.b persistence seams and has no generated
  artifacts.
- **Step 2.c/9 cleanup assessment:** Removed the unused PR-repository session
  read API and made non-list/detail mapping explicitly PR-free. No persisted,
  wire, job, listener, setting, or compatibility artifact became obsolete.
- **Step 2.c/9 merge:** PR #678 merged as `d13cc8ca` with all 11 checks passing,
  Cubic approval, and no unresolved review threads. Step 3 started immediately
  from that merged `main` tip.
- **Step 3/9 implementation:** `GhCliApi` now builds variable-bound GraphQL
  documents for up to 20 exact repository/branch targets and parses normalized
  generated DTOs for open and terminal pages. `PrSourceRepository` filters fork
  and wrong-branch candidates, coalesces cursor work, reads equal-creation-time
  boundaries, selects open before terminal, and fences every response plus one
  final identity check. Target-bound selected/unmatched variants flow to one
  repository-owned atomic cache replacement, so complete no-match clears stale
  rows without exposing API DTOs to the service layer.
- **Step 3/9 verification and review:** The live installed `gh` schema/query was
  rechecked against PR #681 and returned its exact closed terminal projection.
  Fatal-info analysis, 105 focused API/DAO/repository/service/routing/integration
  tests, all 2,314 bridge app tests, code generation, formatting, and
  `git diff --check` pass. `aristotle-impl-review` rejected the first working
  tree because API DTOs escaped into the service, target identity was separable
  from selected PR fields, query failures used nullable coordination fields,
  and new contracts used legacy directories. The findings were applied with
  target-bound repository variants, repository-owned mapping/persistence,
  sealed query exceptions, and current top-level API/repository paths; direct
  corrections were not re-reviewed per policy.
- **Step 3/9 cleanup and size:** Removed repository-wide `gh pr list`,
  per-disappeared-PR `gh pr view`, active-row DAO/repository helpers, incremental
  writer methods, and their obsolete tests/fakes. The approximately 3,300-line
  change exceeds the soft cap because roughly 700 lines are generated DTO output
  and roughly 900 are required deletion of the replaced path. A smaller split
  would ship unused GraphQL machinery or retain two competing source paths.
- **Step 3/9 merge:** PR #685 merged as `f6ec9e9d` with all 11 checks passing,
  Cubic approval, and no unresolved review threads. Review follow-up added
  repeated-cursor termination, privacy-safe typed diagnostics, and the required
  named query-size parameter before merge.
- **Step 4/9 implementation:** Request refresh now resolves every captured root
  session's exact persisted directory through typed named/detached/missing/
  unsupported/failure outcomes, commits current branch/repository scope before
  GitHub work, and maps `Session.branchName` only from current scope. One global
  generation drain batches project sets, queues post-seal same-project requests,
  serializes local/network/write phases, and gates replacement against the
  persisted login and exact current targets.
- **Step 4/9 cleanup and size:** Removed creation-branch target generation,
  project-path/session-directory fallback routing, the per-project active-return
  refresh path, and their obsolete tests/fakes. The approximately 3,700-line
  change replaces roughly 1,000 lines of old service coverage and roughly 700
  lines of persistence/service tests, then adds review-requested checkout and
  directory race fences, explicit-refresh debounce policy, per-project write
  failure isolation, and focused regressions. Splitting local resolution from
  the drain would ship current-branch presentation with the known post-seal
  request-drop race, so the coherent final target is 3,600–3,900 changed lines.
- **Step 4/9 verification and review:** Fatal-info analysis, 79 focused
  Git/source/persistence/service/routing/integration tests, all 2,311 bridge app
  tests, formatting, and `git diff --check` pass. `aristotle-impl-review`
  approved the initial complete working-tree architecture with no findings. A
  follow-up review of the architecture-bearing feedback changes identified two
  contract-shape corrections: use a closed semantic refresh policy and model a
  checkout change as its own typed target variant. Both were applied; per review
  rules, those corrections were not re-reviewed. All 13 bot threads were
  addressed in `a4016fa9` and resolved.

## Findings and Plan Deltas

- **2026-07-31 — Current-branch scope:** Keep one selected PR for the exact
  current branch, with no visited-branch history, filesystem watcher, archive
  PR state, history presentation, or all-state discovery.
- **2026-07-31 — Coworker ownership:** Exact same-repository branch matching has
  no author filter, so coworker-authored PRs are eligible while fork heads remain
  excluded.
- **2026-07-31 — Batched active set:** One connection-scoped active-set
  scheduler batches bounded multi-repository GraphQL targets without
  per-project timers.
- **2026-07-31 — Settings:** Fixed cadence defaults to 30 seconds per bridge,
  supports live client mutation, and intentionally has no JSON file watcher.
- **2026-07-31 — Plan lifecycle:** Keep nine top-level steps with this plan as
  Step 1/9 and active-to-completed retirement as Step 9/9; Step 2 uses ordered
  2.a–2.c substeps after the reviewed implementation exceeded the line cap.
- **2026-07-31 — PR #649 review:** Corrected the reviewed baseline SHA; required
  candidate pagination past newer fork heads, read-time GitHub identity gating,
  a coalesced add-during-flight refresh, and independent branch display for
  named non-GitHub repositories.
- **2026-07-31 — Explicit refresh generation:** Same-project requests arriving
  after cycle admission no longer share potentially stale local evidence; their
  waiter is bound to the immediate follow-up generation.
- **2026-07-31 — Visible-route ownership:** Mounted list/detail cubits are not
  sufficient evidence of viewing. Narrow covered routes clear claims, wide
  visible list panes retain them, and detail child routes hide detail claims.
- **2026-07-31 — Cleanup:** Step 2 replaces the unscoped cache shape; Step 3
  removes repository-wide PR source code and directly obsolete test support.
  Creation-branch storage and the empty compatibility wire field remain because
  they still have required cleanup/transport roles.
- **2026-08-01 — Step 2.b generated overage:** Current Drift generation emits
  both v12 and v13 migration helper classes, increasing the evidence-based target
  to 9,800–10,800 lines. Initial hand-authored production/tests remained within
  the soft cap; required PR review fixes raised them to 1,989 lines. The generated
  schema/migration bundle and coupled correctness fixes must accompany v13
  atomically, so neither overage has a smaller independently valid split.
