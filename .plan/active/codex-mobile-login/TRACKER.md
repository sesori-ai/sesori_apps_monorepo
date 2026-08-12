# Mobile Codex Login: Tracker

## Current State

- **Plan slug:** `codex-mobile-login`
- **Series state:** Steps 1-5 merged; Step 6 PR open
- **Current step:** 6/8
- **Implementation base:** Step 5 merge commit `e13b9a38`
- **Plan PR:** [#824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824)
- **Current PR:** [#837](https://github.com/sesori-ai/sesori_apps_monorepo/pull/837)
- **Next action:** Monitor Step 6 and implement Step 7 locally

## Plan Review

- **Verdict:** Initial draft rejected with two actionable findings; both applied
  directly; corrected draft intentionally not re-reviewed merely for approval
- **Reviewer:** `architecture-plan-review`
- **Reviewed scope:** Proposed mobile Codex login architecture across plugin
  interface, Codex plugin, bridge app, shared contracts, client core, and mobile
  presentation
- **Applied findings:** Codex authentication now has explicit Client, API,
  Repository, and Service ownership; terminal shared progress is a sealed model
  with failure-only message data

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [x] | 1/8 | `🌱 [codex-mobile-login] docs: plan mobile Codex login [step 1/8]` | 450-850 | [PR #824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824) merged |
| [x] | 2/8 | `⚙️ [codex-mobile-login] refactor(codex): prepare authentication primitives [step 2/8]` | 850-1,400 | [PR #827](https://github.com/sesori-ai/sesori_apps_monorepo/pull/827) merged |
| [x] | 3/8 | `🚧 [codex-mobile-login] feat(codex): implement device authentication [step 3/8]` | 850-1,450 | [PR #833](https://github.com/sesori-ai/sesori_apps_monorepo/pull/833) merged |
| [x] | 4/8 | `⚙️ [codex-mobile-login] feat(protocol): describe harness authentication [step 4/8]` | 650-1,200 | [PR #834](https://github.com/sesori-ai/sesori_apps_monorepo/pull/834) merged |
| [x] | 5/8 | `🚧 [codex-mobile-login] feat(bridge): expose harness authentication [step 5/8]` | 950-1,500 | [PR #835](https://github.com/sesori-ai/sesori_apps_monorepo/pull/835) merged |
| [ ] | 6/8 | `🚧 [codex-mobile-login] feat(client): orchestrate harness authentication [step 6/8]` | 900-1,500 | [PR #837](https://github.com/sesori-ai/sesori_apps_monorepo/pull/837) open |
| [ ] | 7/8 | `⚙️ [codex-mobile-login] feat(app): add mobile Codex login [step 7/8]` | 750-1,350 | Pending |
| [ ] | 8/8 | `🌱 [codex-mobile-login] docs: retire mobile Codex login plan [step 8/8]` | 50-200 | Pending |

## Locked Decisions

- V1 supports login only for authentication-required Codex setup.
- Device authorization is owned and completed by Codex on the bridge machine.
- Sesori transports only the verification URL, user code, and sanitized state.
- Backend-specific authentication remains inside each concrete plugin.
- One optional backend-neutral descriptor capability is the only shared plugin
  seam; no generic OAuth framework is introduced.
- One active operation per plugin is start-or-join across retries and surfaces.
- Setup reinspection, not browser or App Server completion alone, determines
  success and routability.
- The system browser opens only after explicit user action; sheet dismissal does
  not cancel.
- No tokens, credential files, account identifiers, challenge data in logs, or
  authentication analytics are allowed.
- Logout, account switching, API-key/token entry, mobile callbacks, and other
  harness implementations are excluded.

## Verification Log

- Step 1: `git diff --check origin/main...HEAD` passes, and
  `git diff --numstat origin/main...HEAD` reports 739 additions and 0 deletions
  across the two plan documents, within the 450-850 target. No Dart/Flutter
  suites were run because this step changes documentation only. Committed as
  `e4213ff2`, pushed, and opened as
  [PR #824](https://github.com/sesori-ai/sesori_apps_monorepo/pull/824).
- Step 2: `dart test` passes all 348 Codex plugin tests. Focused runtime,
  setup, stdio transport, and typed account API tests pass, and
  `dart analyze --fatal-infos` reports no issues.
  `git diff --check origin/main...HEAD` passes, and
  `git diff --numstat origin/main...HEAD` reports 2,478 additions and 169 deletions.
  The required architecture implementation review could not run because the
  review sub-agent failed twice before reading code with an internal task-store
  schema error (`no such column: replacement_seq`). Committed as `3d71e4cf`,
  rebased onto `origin/main`, pushed, and opened as
  [PR #827](https://github.com/sesori-ai/sesori_apps_monorepo/pull/827).
- Step 3: `dart test` passes all 152 plugin-interface tests and all 357 Codex
  plugin tests. `dart analyze --fatal-infos` reports no issues in both packages,
  `git diff --check origin/main...HEAD` passes, and
  `git diff --numstat origin/main...HEAD` reports 850 additions and 27 deletions.
  The required architecture implementation
  review could not run because the review sub-agent failed before reading code
  with the internal task-store schema error `no such column: replacement_seq`.
  Committed as `36ec1eca`, pushed, and opened as
  [PR #833](https://github.com/sesori-ai/sesori_apps_monorepo/pull/833).
- Step 4: Full `sesori_shared` tests pass (389 tests), focused client SSE
  classification tests pass, and fatal-info analysis reports no issues in
  `sesori_shared`, bridge app, client core, desktop core, mobile app, or desktop
  app. The required architecture implementation review could not run because
  the review sub-agent failed before reading code with the internal task-store
  schema error `no such column: replacement_seq`. `git diff --check
  origin/main...HEAD` passes, and `git diff --numstat origin/main...HEAD` reports 976
  additions and 25 deletions. Committed as `0b418a3a`, pushed, and opened as
  [PR #834](https://github.com/sesori-ai/sesori_apps_monorepo/pull/834).
- Step 5 local: Full bridge app tests pass (2,542 tests), full Codex tests pass
  (361 tests), and full plugin-interface tests pass (152 tests). Fatal-info
  analysis reports no issues in all three packages. The required architecture
  implementation review could not run because the review sub-agent failed
  before reading code with the internal task-store schema error `no such
  column: replacement_seq`. Post-rebase focused tests pass (123 bridge app,
  14 Codex descriptor, and plugin-interface authentication tests), fatal-info
  analysis remains clean, `git diff --check origin/main...HEAD` passes, and
  `git diff --numstat origin/main...HEAD` reports 844 additions and 73
  deletions. The lower-than-estimated size reflects reuse of existing lifecycle
  ownership rather than introducing a parallel coordinator. Pushed and opened
  as [PR #835](https://github.com/sesori-ai/sesori_apps_monorepo/pull/835).
- Step 6 local: After rebasing onto Step 5 merge commit `e13b9a38`, full
  `module_core` tests pass (1,054 tests), focused API,
  repository, service, and cubit authentication tests pass (78 tests), and
  fatal-info analysis is clean in `module_core` and the mobile app. Coverage
  includes typed routes, conflict and response-loss mapping, absolute HTTPS
  challenge validation, fast terminal SSE ordering, reconnect fencing,
  explicit browser launch, cancellation, and terminal presentation. The
  required architecture implementation review could not run because the
  review sub-agent failed before reading code with the internal task-store
  schema error `no such column: replacement_seq`. `git diff --check
  origin/main...HEAD` passes and the production/test/doc scope contains 1,581
  additions and 22 deletions. The small overage above the 1,500-line target is
  generated Freezed state plus focused API, repository, service, and cubit race
  coverage required by the security-sensitive cross-layer flow.

## Findings And Plan Deltas

- **2026-08-11 - Product scope:** The user selected login-only Codex v1 and
  explicitly deferred logout and account switching.
- **2026-08-11 - Upstream protocol:** Codex App Server device authentication
  exists from `0.118.0`; current Sesori minimum `0.139.0` and managed `0.146.0`
  require no version change.
- **2026-08-11 - Cross-device flow:** Normal Codex browser login is excluded
  because its callback targets localhost on the bridge machine; device code is
  the supported headless/cross-device path.
- **2026-08-11 - Plugin boundary:** Plugin implementations remain concrete and
  independent; the shared contract carries capability, challenge, and progress
  only.
- **2026-08-11 - Architecture review:** Added explicit Codex Client/API/
  Repository/Service layers and changed terminal progress to sealed variants.
- **2026-08-11 - Cleanup:** Reuse one Codex runtime selection service and replace
  local-terminal-only setup guidance; retain login-status inspection and
  compatibility behavior.
- **2026-08-11 - Step 2 started:** Created local branch
  `codex-mobile-login-primitives` from the Step 1 branch. Confirmed the runtime
  selection service must preserve explicit/PATH/desktop/managed precedence and
  setup failure classifications; the new stdio client will be a second
  transport behind the typed Codex App Server API rather than changing the
  normal WebSocket runtime.
- **2026-08-11 - Step 2 implementation:** Added one shared executable selection
  decision for setup/startup/authentication, a secret-safe stdio JSONL App
  Server transport with bounded child cleanup, and typed account start/cancel/
  completion API models. Existing WebSocket generation behavior remains
  unchanged and no bridge or client capability is exposed yet.
- **2026-08-11 - Step 3 started:** Created local branch
  `codex-mobile-login-device-authentication` from the Step 2 PR branch. It
  remains local until Step 2 merges.
- **2026-08-12 - Step 3 implementation:** Added the optional descriptor
  capability and safe sealed events, then composed Codex Client/API/Repository/
  Service ownership with private login-ID correlation, HTTPS validation,
  abort-driven upstream cancellation, sanitized remote failures, and awaited
  child cleanup. No route or client capability is exposed yet.
- **2026-08-12 - Step 4 started:** Created local branch
  `codex-mobile-login-shared-contracts` from the Step 3 PR branch. It remains
  local until Step 3 merges.
- **2026-08-12 - Step 3 merged:** Rebased Step 4 onto merge commit `3af28a81`
  after PR #833 merged with cancellation-precedence review fixes.
- **2026-08-12 - Step 4 implementation:** Added backend-neutral authentication
  capability/state metadata, typed device-code challenge, sealed terminal
  progress, typed conflicts, and one global progress SSE event. Challenge data
  remains request-scoped and absent from management snapshots and SSE.
- **2026-08-12 - Step 5 started:** Created local branch
  `codex-mobile-login-bridge-authentication` while Step 4 remains in review.
- **2026-08-12 - Step 5 implementation:** Extended the existing runtime,
  repository, lifecycle service, explicit router, and Orchestrator ownership
  seams with start-or-join authentication, typed conflicts, cancellation,
  authoritative setup reinspection/start, terminal SSE, and awaited shutdown
  settlement. The successor remains local until Step 4 merges.
- **2026-08-12 - Step 4 merged:** Rebased Step 5 onto merge commit `2bc60ae3`
  after PR #834 merged with fail-closed future-progress compatibility.
- **2026-08-12 - Step 6 implementation:** Added typed authentication transport
  and repository outcomes, connection- and bridge-fenced service correlation,
  ephemeral HTTPS-only challenges, fast-terminal retention, and independent
  cubit presentation state with explicit browser launch and cancellation. No
  authentication control is rendered yet; Step 7 owns presentation.
- **2026-08-12 - Step 5 review:** Addressed all three Qodo threads in
  `bc0cb552`: active operations now always own a non-null abort seam,
  cancellation remains authoritative through setup-inspection failure, and
  plugin-controlled failure details remain local while wire progress uses a
  fixed safe message. PR #835 is green, approved, mergeable, and has zero
  unresolved threads.
