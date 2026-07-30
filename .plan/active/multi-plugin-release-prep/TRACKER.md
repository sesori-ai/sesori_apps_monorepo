# Multi-Plugin Release Preparation: Tracker

## Current State

- **Implementation base:** `origin/main` at `57e0fffb`
- **Series state:** Steps 1/6 and 2/6 are merged; Step 3/6 PR #616 is open from
  `multi-plugin-release-prep-plugin-options`
- **Current step:** Step 3/6 — aggregate scoped plugin options
- **Next action:** review and merge PR #616, then start Step 4/6 from updated
  `origin/main`

## Delivery

| Done | Step | Branch | PR state |
|---|---|---|---|
| [x] | Step 1/6 — plan multi-plugin release preparation | `multi-plugin-release-prep` | PR #605 merged |
| [x] | Step 2/6 — type Codex session-option discovery | `multi-plugin-release-prep-codex-options` | PR #609 merged |
| [ ] | Step 3/6 — aggregate scoped plugin options | `multi-plugin-release-prep-plugin-options` | PR #616 open |
| [ ] | Step 4/6 — durable bridge cache and aggregate route | `multi-plugin-release-prep-bridge-cache` | Blocked on Step 3 merge |
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
4. `[multi-plugin-release-prep] feat(bridge): cache scoped session options [step 4/6]`
5. `[multi-plugin-release-prep] feat(client): consume cached session options [step 5/6]`
6. `[multi-plugin-release-prep] refactor(app): consolidate Harness settings [step 6/6]`

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
  failure. Generated the Freezed source. All 3,207 tests across plugin interface,
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
  newer live model or mode state. The full owning-package suites plus fatal
  analysis passed after each fix round.
