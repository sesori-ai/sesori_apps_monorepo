# Multi-Plugin Release Preparation: Tracker

## Current State

- **Implementation base:** `origin/main` at `5eabfd0d`
- **Series state:** Steps 1/6 through 3/6 are merged; oversized PR #620 is frozen
  as a draft and replaced by the stacked Step 4.A/6 through 4.F/6 sequence
- **Current step:** Step 4.B/6 — scoped cache schema and runtime database
- **Next action:** verify and open the stacked Step 4.B/6 PR

## Delivery

| Done | Step | Branch | PR state |
|---|---|---|---|
| [x] | Step 1/6 — plan multi-plugin release preparation | `multi-plugin-release-prep` | PR #605 merged |
| [x] | Step 2/6 — type Codex session-option discovery | `multi-plugin-release-prep-codex-options` | PR #609 merged |
| [x] | Step 3/6 — aggregate scoped plugin options | `multi-plugin-release-prep-plugin-options` | PR #616 merged |
| [ ] | Step 4.A/6 — wire contracts and runtime seams | `multi-plugin-release-prep-bridge-contracts` | PR #623 open |
| [ ] | Step 4.B/6 — scoped cache schema/runtime database | `multi-plugin-release-prep-cache-schema` | In progress |
| [ ] | Step 4.C/6 — migration and DAO verification | `multi-plugin-release-prep-cache-verification` | Blocked on 4.B |
| [ ] | Step 4.D/6 — capture/persistence repository | `multi-plugin-release-prep-cache-repository` | Blocked on 4.C |
| [ ] | Step 4.E/6 — cache policy/coalescing service | `multi-plugin-release-prep-cache-service` | Blocked on 4.D |
| [ ] | Step 4.F/6 — route, listeners, and lifecycle wiring | `multi-plugin-release-prep-cache-route` | Blocked on 4.E |
| [ ] | Step 5/6 — cached New Session client flow | `multi-plugin-release-prep-client-options` | Blocked on Step 4 merge |
| [ ] | Step 6/6 — consolidated Harnesses settings | `multi-plugin-release-prep-harness-settings` | Blocked on Step 5 merge |

## Locked Decisions

- One endpoint: `POST /session/options`; `refresh=true` is the only activating
  aggregate read and also forces backend catalog discovery instead of reusing a
  plugin's tracker snapshot.
- OpenCode and Codex cache per project. Cursor caches once per plugin. Codex
  stays project-aware because defaults and skills depend on project context.
- Cache-only miss is explicit unavailable, not an empty successful catalog.
- Additive plugin discovery capability identifies an old bridge before the
  aggregate call; a capable bridge's typed project failure never triggers legacy
  fallback.
- Typed session-options errors distinguish cache miss, project absence, refresh
  failure with valid retained data, and refresh failure requiring option
  clearing. Plugin/runtime failures normalize to 502 so transport-reserved 401
  remains Sesori authentication only.
- Legacy option routes stay unchanged. New-client/old-bridge live loading occurs
  only after explicit Refresh.
- The bridge is the durable cache authority; no new client persistence/cache is
  introduced.
- Plugin facades delegate aggregate behavior to plugin services. Codex transport
  parsing is typed; ACP model/provider state belongs to a tracker, not a mapper.
- `SessionOptionsService` owns scope, retention, completeness, coalescing, and
  CAS retry policy. The repository owns mechanical capture/persistence and
  runtime generation fencing.
- Coalescing is intent-aware: explicit refresh overlapping automatic reuse
  queues and awaits one forced-discovery tail.
- Partial observations seed only an empty cache; they never replace retained
  partial or complete data from independently successful sources.
- Forced-discovery failure is a distinct plugin result and never collapses into
  a successful partial observation.
- ACP command advertisement emits a dedicated generation-attributed
  options-change event so Cursor's plugin-scoped cache is refreshed after the
  authoritative command snapshot arrives; both live and replay deferral paths
  forward backend session identity, which the service resolves to the stable
  persisted project binding.
- Harnesses settings ends as one screen and one screen-owned management cubit,
  using Prego sheets and setup/capability-aware visibility.
- Harness consolidation preserves authoritative `bridgeId` snapshot fencing;
  retained management state from bridge A never renders while actions target
  bridge B.

## Exact PR Titles

1. `[multi-plugin-release-prep] docs: plan multi-plugin release preparation [step 1/6]`
2. `[multi-plugin-release-prep] refactor(codex): type session option discovery [step 2/6]`
3. `[multi-plugin-release-prep] feat(bridge): aggregate scoped plugin options [step 3/6]`
4. `[multi-plugin-release-prep] feat(bridge): add session option wire contracts [step 4.A/6]`
5. `[multi-plugin-release-prep] feat(bridge): persist scoped session option rows [step 4.B/6]`
6. `[multi-plugin-release-prep] test(bridge): verify session option cache migration [step 4.C/6]`
7. `[multi-plugin-release-prep] feat(bridge): capture scoped session options [step 4.D/6]`
8. `[multi-plugin-release-prep] feat(bridge): apply session option cache policy [step 4.E/6]`
9. `[multi-plugin-release-prep] feat(bridge): expose cached session options [step 4.F/6]`
10. `[multi-plugin-release-prep] feat(client): consume cached session options [step 5/6]`
11. `[multi-plugin-release-prep] refactor(app): consolidate Harness settings [step 6/6]`

## Verification Log

- Step 1/6 (2026-07-29): finalized the scope-aware aggregate session-options
  and single-screen Harnesses settings plan. `git diff --check` passed; no
  Dart/Flutter suites were run for this documentation-only slice. Committed as
  `3c46773c`, pushed, opened as PR #605, and merged to `main` as `fb961d16`.
- Step 2/6 (2026-07-29): added typed Codex `model/list` DTO/API/repository
  ownership, moved model and collaboration-option construction into
  `CodexSessionService`, and reduced the plugin facade to route delegation.
  Generated Freezed/JSON sources, all 204 Codex package tests, focused fatal
  analysis, formatting, and `git diff --check` passed. Aristotle implementation
  review approved the branch-local architecture with no findings. Committed as
  `4773ddde`, pushed, opened as PR #609, and merged to `main` as `57e0fffb`.
- Step 3/6 (2026-07-30): added the required aggregate, completeness, discovery,
  and descriptor-scope contracts; implemented project-scoped OpenCode and Codex
  aggregates; moved ACP configuration and aggregate state into injected tracker
  and service peers; and added the dedicated command-advertisement options event
  through live and replay paths. Cursor now owns one plugin-scoped service with
  bounded reuse and forced discovery that stages both catalog and command state,
  commits them together on success, and preserves the last-good aggregate on
  failure. Generated the Freezed source. All 3,208 tests across plugin interface,
  OpenCode, Codex, ACP, Cursor, and bridge app passed, as did
  `dart analyze --fatal-infos` in all six modules and `git diff --check`.
  Aristotle implementation review identified the command-staging and ACP peer
  composition gaps; both were addressed, and the second/final implementation
  review approved the corrected architecture. Committed as `81ce51e5`, pushed,
  and opened as PR #616. Review follow-up hardened malformed ACP command
  snapshots and replay-failure signaling, and revision-fenced Cursor catalog
  commits so reconnects and concurrent live updates preserve coherent commands;
  a subsequent follow-up also preserved OpenCode's typed parallel-discovery
  errors and fenced both reuse and forced Cursor catalog replacement against
  newer live model or mode state. Forced refresh also invalidates a prior
  command snapshot when the refresh observes no authoritative command update.
  The full owning-package suites plus fatal analysis passed after each fix
  round. PR #616 merged to `main` as `5eabfd0d`.
- Step 4/6 planning refresh (2026-07-30): mapped the merged codebase's exact
  shared-model, Drift v12, runtime, repository/service, route, capability,
  listener, session-binding, Orchestrator lifecycle, and focused-test seams.
  The implementation map is recorded in `PLAN.md`.
- Step 4/6 implementation (2026-07-30): added shared success/error and discovery
  capability contracts; Drift schema v12 scoped persistence; generation-fenced
  capture and CAS; retention, completeness, and intent-aware coalescing policy;
  the typed aggregate route; stable-project binding attribution; and independent
  creation/options-change refresh listeners. Generated shared and Drift sources.
  All 348 shared tests and 2,239 bridge-app tests passed, as did fatal analysis
  in both owning packages and `git diff --check`. Aristotle's first
  implementation review identified new Drift import cycles; the cache DAO was
  moved to composition-root construction and the cache table now uses Drift's
  generated row without importing the database or legacy project table module.
  The second/final review approved the corrected architecture. Opened PR #620.
- Step 4 split (2026-07-30): the user rejected PR #620's 10,045-line review
  size. Converted it to draft, stopped monitoring it, and froze the branch as
  the implementation source. Replaced Step 4 with fixed stacked substeps 4.A
  through 4.F, each targeting roughly 1,500 changed lines including generated
  output.
- Step 4.A/6 preparation (2026-07-30): added shared aggregate success/error and
  discovery-capability contracts, immutable descriptor scope composition, and
  activating generation capture. Generated shared models; 12 shared and 97
  bridge focused tests passed with fatal analysis in both owning packages and
  `git diff --check`. Aristotle approved the revised six-substep delivery plan
  and the Step 4.A implementation architecture without findings.
- Step 4.B/6 preparation (2026-07-30): added the Drift v12 cache table,
  standalone DAO, generated runtime database, migration steps, and
  current-schema cascade smoke coverage. The 2 focused persistence tests and
  bridge-app fatal analysis passed with `git diff --check`. Aristotle approved
  the stacked implementation boundary without findings.
